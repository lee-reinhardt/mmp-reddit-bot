#!/usr/bin/env ruby

require 'pp'
require 'json'
require 'http'
require 'redd'
require 'sqlite3'
require 'nokogiri'
require 'syslogger'
require 'soundcloud'

class Bot

  def initialize
    @db     = SQLite3::Database.new(__dir__ + '/db/burr.sqlite3')
    @config = JSON.parse File.read(__dir__ + '/config.json')
    @logger = Syslogger.new('mmpbot', Syslog::LOG_PID, Syslog::LOG_LOCAL0)
  end

  def run
    libsyn_eps.each do |ep|
      next if not fresh_post ep

      if db_link_exists ep[:link]
        @logger.info "skipping link '#{ep[:link]}' (in db)"
        next
      end

      @logger.info "new episode, link '#{ep[:link]}'"

      db_add ep

      reddit_post = reddit_post ep

      ep = ep.merge({
        reddit_id:          reddit_post[:id],
        reddit_name:        reddit_post[:name],
        reddit_link:        reddit_post[:url],
        reddit_created_ts:  DateTime.now.strftime('%Y-%m-%d %H:%M:%S')
      })

      db_reddit_update ep
    end
  end

  def libsyn_eps
    return libsyn_parse libsyn_fetch
  end

  def libsyn_fetch
    req = HTTP.get('http://billburr.libsyn.com/rss')

    if req.status != 200
      raise "bad status code '#{req.status}' from site"
    end

    return req.body.to_s
  end

  def libsyn_parse text
    xml = Nokogiri::XML(text)
    eps = []

    xml.xpath('//channel/item').each do |item|
      eps.push({
        link:       item.css('link').text,
        title:      item.css('title').text,
        info:       item.css('description').text.gsub(/<\/?[^>]*>/, ''), # strip <p> tags
        created_ts: DateTime.parse(item.css('pubDate').text).strftime('%Y-%m-%d %H:%M:%S') # todo: normalize timezones
      })
    end

    return eps
  end

  def fresh_post ep
    hrs_since_post = ((DateTime.now - DateTime.parse(ep[:created_ts])) * 24).to_i

    if hrs_since_post >= @config['max_age_hrs']
      @logger.info "skipping link '#{ep[:link]}' (#{hrs_since_post} hrs old)"
      return false
    end

    return true
  end

  def reddit_post ep
    reddit = Redd.it(:script,
      @config['reddit_client_id'],
      @config['reddit_client_secret'],
      @config['reddit_username'],
      @config['reddit_password'],
      user_agent: "MMP Bot v0.1")

    reddit.authorize!

    title = ep[:title] + ' | ' + ep[:info]
    text =
<<-TEXT
# #{ep[:title]}

## #{ep[:info]}

#{ep[:link]}
TEXT

    begin
      @logger.info "submitting link: #{ep[:link]}"

      return reddit.subreddit_from_name(@config['subreddit_name'])
                   .submit(title, text: text, sendreplies: false)
    rescue => e
      @logger.error("failed to submit reddit post, '#{e}'\n#{e.backtrace}")
      raise e
    end

    return nil
  end

  def db_add ep
    begin
      return @db.execute('insert into burr (link, title, info, created_ts) VALUES (?, ?, ?, ?)',
                 [ ep[:link], ep[:title], ep[:info], ep[:created_ts] ])
    rescue => e
      @logger.error("failed to insert link '#{ep[:link]}', '#{e}'")
      raise e
    end
  end

  def db_reddit_update ep
    begin
      return @db.execute('update burr set reddit_created_ts = ?, reddit_id = ?, reddit_name = ?, reddit_link = ? where link = ?',
                 [ ep[:reddit_created_ts], ep[:reddit_id], ep[:reddit_name], ep[:reddit_link], ep[:link] ])
    rescue => e
      @logger.error("failed to update link '#{ep[:link]}', '#{e}'")
      raise e
    end
  end

  def db_link_exists link
    begin
      return @db.execute('select * from burr where link = ?', [link]).length === 1
    rescue => e
      @logger.error("failed to query for link '#{link}', '#{e}'")
      raise e
    end
  end

end

# main method
if __FILE__ == $0
  bot = Bot.new
  bot.run
end
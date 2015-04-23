#!/usr/bin/env ruby

require 'pp'
require 'json'
require 'http'
require 'redd'
require 'sqlite3'
require 'nokogiri'
require 'soundcloud'

class Bot

  def initialize
    @db     = SQLite3::Database.new './db/burr.sqlite3'
    @config = JSON.parse File.read  './config.json'
    @reddit = nil
  end

  def run
    eps = burr_analyze_list burr_scrape

    eps.each do |ep|
      next if db_link_exists ep[:burr_link]

      sc_track_id = burr_analyze_ep burr_scrape ep[:burr_link]
      sc_track    = soundcloud_fetch sc_track_id

      next if sc_track.nil?

      ep = ep.merge({
        sc_title:      sc_track['title'],
        sc_track_id:   sc_track_id,
        sc_created_ts: DateTime.parse(sc_track['created_at']).strftime('%Y-%m-%d %H:%M:%S')
      })

      next if db_scid_exists ep[:sc_track_id]

      db_add ep

      reddit_post = reddit_post ep

      ep = ep.merge({
        reddit_created_ts: DateTime.now.strftime('%Y-%m-%d %H:%M:%S'),
        reddit_id: reddit_post[:id],
        reddit_name: reddit_post[:name],
        reddit_link: reddit_post[:url]
      })

      db_reddit_update ep
    end

  end

  def load_reddit
    return if ! @reddit.nil?

    @reddit = Redd.it(:script,
      @config['reddit_client_id'],
      @config['reddit_client_secret'],
      @config['reddit_username'],
      @config['reddit_password'],
      user_agent: "MMP Bot v0.1")
    @reddit.authorize!
  end

  def burr_scrape link = nil
    link = link.nil? ? "http://www.billburr.com/podcast" : link
    req  = HTTP.get(link)

    if req.status != 200
      raise "Bad status code '#{req.status}' from site"
    end

    return req.body.to_s
  end

  def burr_analyze_list body
    eps = Array.new

    Nokogiri::HTML(body).css('article.post div.holder h2 a').each do |post|
      link = post.attribute('href').value
      info = post.css('p').first.children.to_s

      eps.push({ burr_link: link, burr_info: info })
    end

    return eps
  end

  def burr_analyze_ep body
    iframe = Nokogiri::HTML(body).css('iframe')

    return nil if iframe.nil? || iframe.length === 0

    src   = iframe.attribute('src').value
    match = /.+\/tracks\/(\d+).*/.match(src)

    return match.nil? ? nil : match[1]
  end

  def soundcloud_fetch sc_track_id = nil
    return nil if sc_track_id.nil?

    client = Soundcloud.new(:client_id => @config['soundcloud_client_id'])

    begin
      # /users/24758916/tracks
      return client.get("/tracks/#{sc_track_id}")
    rescue
      # @todo log
      puts "failed to find sc_track_id '#{sc_track_id}'"
    end

    return nil
  end

  def reddit_post ep
    load_reddit

    title = ep[:sc_title] + ' | ' + ep[:burr_info]
    link  = ep[:burr_link]

    begin
      return @reddit.subreddit_from_name(@config['subreddit_name'])
                    .submit(title, url: link)
    rescue
      # @todo log
      raise 'failed to submit reddit post'
    end

    return nil
  end

  def db_add ep
    puts "inserting #{ep[:sc_track_id]}"

    begin
      return @db.execute('insert into burr (sc_track_id, sc_created_ts, sc_title, burr_link, burr_info) VALUES (?, ?, ?, ?, ?)',
                 [ ep[:sc_track_id], ep[:sc_created_ts], ep[:sc_title], ep[:burr_link], ep[:burr_info] ])
    rescue
      # @todo log
      raise 'db error: insert failed'
    end
  end

  def db_reddit_update ep
    puts "updating #{ep[:sc_track_id]}"

    begin
      return @db.execute('update burr set reddit_created_ts = ?, reddit_id = ?, reddit_name = ?, reddit_link = ? where sc_track_id = ?',
                 [ ep[:reddit_created_ts], ep[:reddit_id], ep[:reddit_name], ep[:reddit_link], ep[:sc_track_id] ])
    rescue
      # @todo log
      raise 'db error: insert failed'
    end
  end

  def db_scid_exists scid
    begin
      return @db.execute('select * from burr where sc_track_id = ?', [scid]).length === 1
    rescue
      # @todo log
      raise 'db error: scid select failed'
    end
  end

  def db_link_exists link
    begin
      return @db.execute('select * from burr where burr_link = ?', [link]).length === 1
    rescue
      # @todo log
      raise 'db error: link select failed'
    end
  end

end

# main method
if __FILE__ == $0
  bot = Bot.new
  bot.run
end
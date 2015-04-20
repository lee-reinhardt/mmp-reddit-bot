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
      sc_track_id = burr_analyze_ep burr_scrape ep[:link]
      sc_track    = soundcloud_fetch sc_track_id

      if sc_track.nil?
        puts "failed to find soundcloud track"
        next
      end

      ep = ep.merge({ title: sc_track['title'], sc_track_id: sc_track_id })

      if db_exists ep
        puts "skipping #{sc_track_id}, already in db"
      else
        db_add ep
        # pp new_post ep[:link], ep[:title] + ' | ' + ep[:info]
      end
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

      eps.push( { link: link, info: info } )
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

  def new_post link, title
    load_reddit

    begin
      return @reddit.subreddit_from_name(@config['subreddit_name'])
                    .submit(title, url: link)
    rescue
      # @todo log
      raise 'failed to submit reddit post'
    end

    return nil
  end

  def db_exists ep
    begin
      return @db.execute('select * from burr where sc_track_id = ?', [ ep[:sc_track_id] ]).length === 1
    rescue
      # @todo log
      raise 'db error: select failed'
    end
  end

  def db_add ep
    puts "inserting #{ep[:sc_track_id]}"

    begin
      @db.execute("insert into burr (sc_track_id, title, link, created_ts) VALUES (?, ?, ?, datetime('now'))",
                 [ ep[:sc_track_id], ep[:title], ep[:link] ])
    rescue
      # @todo log
      raise 'db error: insert failed'
    end
  end

end

# main method
if __FILE__ == $0
  bot = Bot.new
  bot.run
end
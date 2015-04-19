#!/usr/bin/env ruby

require 'pp'
require 'json'
require 'http'
require 'redd'
require 'nokogiri'
require 'soundcloud'

class Bot

  def initialize
    @config = JSON.parse(File.read('./config.json'))
    @reddit = nil
  end

  def run
    # pp soundcloud_fetch
    # pp burr_analyze burr_fetch
  end

  def load_reddit
    if not @reddit.nil?
      return
    end

    @reddit = Redd.it(:script,
      @config['reddit_client_id'],
      @config['reddit_client_secret'],
      @config['reddit_username'],
      @config['reddit_password'],
      user_agent: "MMP Bot v0.1")
  end

  def burr_fetch
    req = HTTP.get("http://www.billburr.com/podcast")

    if req.status != 200
      raise "Bad status code '#{req.status}' from site"
    end

    return req.body.to_s
  end

  def burr_analyze body
    eps = Array.new

    Nokogiri::HTML(body).css('article.post div.holder h2 a').each do |post|
      link = post.attribute('href').value
      info = post.css('p').first.children.to_s

      eps.push( { link: link, info: info } )
    end

    return eps
  end

  def soundcloud_fetch
    client = Soundcloud.new(:client_id => @config['soundcloud_client_id'])

    tracks = client.get('/users/24758916/tracks', :limit => 1)

    tracks.each do |track|
      # pp track
    end
  end

  def new_post link, title
    load_reddit

    submission = @reddit.subreddit_from_name(@config['subreddit_name'])
                        .submit(title, url: link)
    pp submission
  end

end

# main method
if __FILE__ == $0
  bot = Bot.new
  bot.run
end
#!/usr/bin/env ruby
require File.expand_path('../../config/environment', __FILE__)
require 'pry'
require 'json'
require 'logger'

require 'sqlite3'
require 'active_record'

# google chrome history
ActiveRecord::Base.establish_connection({:adapter => "sqlite3", :database => File.expand_path("~/Library/Application Support/Google/Chrome/Default/History") })

# rather than inspecting the schema on each of the tables, ActiveRecord has a
# module SchemaDumper that generates a very readable schema dump:
puts ActiveRecord::SchemaDumper.dump

# declared a new model
class Url < ActiveRecord::Base

  # create a hash named after the title of the video for all matches to the
  # youtube_address.
  def youtube_urls_hash
    result = {}
    youtube_address = /[h][t][t][p][s]\:\/\/[w][w][w]\.[y][o][u][t][u][b][e]\.[c][o][m]\/[w][a][t][c][h]/

    Url.all.each {|attr| result[attr.title] = {
      url: attr.url,
      visit_count: attr.visit_count,
      last_visit: attr.last_visit_time} if attr.url =~ youtube_address
    }.compact
    return result
  end

  # the days youtube views
  # does it need to be stored in the database?
  # cron task every few mins or hour?
  #
  # create a model
  # create a method that checks date, time and viewcount.

end

# create a instance of Url
youtube = Url.new

# hash of youtube urls
youtube.youtube_urls_hash



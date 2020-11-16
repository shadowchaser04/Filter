#!/usr/bin/env ruby
require File.expand_path('../../config/environment', __FILE__)
require 'pry'
require 'json'
require 'logger'
require 'sqlite3'
require 'active_record'

module YoutubeHistory
  #{{{1 methods
  # google chrome history
  def connect_to_chrome
    ActiveRecord::Base.establish_connection({
      :adapter => "sqlite3",
      :database => File.expand_path("~/Library/Application Support/Google/Chrome/Default/History")
    })
  end

  def connect_to_safari
    ActiveRecord::Base.establish_connection({
      :adapter => "sqlite3",
      :database => File.expand_path("~/Library/Safari/History.db")
    })
  end

  # re-establish_connection to rails db
  def connect_to_rails
    ActiveRecord::Base.establish_connection
  end

  #}}}
  #{{{1 chrome
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
        last_visit: time_stamps(attr.last_visit_time) } if attr.url =~ youtube_address
      }.compact
      return result
    end


    # convert chrome timestamps
    def time_stamps(time)

      chrome_timestamp = time

      # Get the January 1601 unixepoch
      since_epoch = DateTime.new(1601,1,1).to_time.to_i

      # Transfrom Chrome timestamp to seconds and add 1601 epoch
      final_epoch = (chrome_timestamp / 1000000) + since_epoch

      # Print DateTime
      date = DateTime.strptime(final_epoch.to_s, '%s')

      # with formating
      #date.strftime('%A, %B %-d, %Y %-I:%M:%S %p')

    end

    # rather than inspecting the schema on each of the tables, ActiveRecord has a
    # module SchemaDumper that generates a very readable schema dump:
    def schema
      begin
        ActiveRecord::SchemaDumper.dump
      rescue Exception => e
        puts "#{e}"
      end
    end

  end
#}}}
end

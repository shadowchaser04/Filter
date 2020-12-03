#!/usr/bin/env ruby
require File.expand_path('../../config/environment', __FILE__)
require 'pry'
require 'json'
require 'logger'

require_relative 'logging'
require_relative 'y_t_history'
require_relative 'y_t_process'

# {{{1 Class: SubtitleDownloader

class YTDownloader

  include Logging

  attr_accessor :filepaths,

  def initialize
    @root_dir = "/Users/shadowchaser/Downloads/Youtube_Subtitles/Subs/"
    @filepaths = nested_hash
    @logger = logger_output(STDOUT)
  end

  # Uses youtube-dl to download subtitles and json file to.
  # ~/Downloads/Youtube/subs/
  def youtube_subtitles(address)
      system("youtube-dl --youtube-skip-dash-manifest --skip-download --write-auto-sub --sub-format best --no-playlist --sub-lang en  --write-info-json \'#{address}\'")
  end

  # Creates and array of absolute filepaths.
  def sub_dir(directory_location)
    raise ArgumentError, "Argument must be a String" unless directory_location.class == String
    Dir.glob(directory_location + "/**/*").select{ |f| File.file? f }
  end

  # Pass in a date range of days to search backwards in the chrome history.
  def chrome_date_range(date_range=1)
    raise ArgumentError, "Argument must be a Integer" unless date_range.class == Integer
    Chrome.where(:last_visit => date_range.days.ago..date_range.days.from_now).pluck(:url)
  end

  # Here we're saving the returned value of the chrome_date_range method
  # invocation in a variable called youtube_history. we loop over the variable
  # passing each youtube url to the youtube_subtitles method downloading the
  # json and vtt files to the ~/downloads/subs/*

  def download_subtitles(int)
    raise ArgumentError, "Argument must be a Integer" unless int.class == Integer
    raise "There where no chrome records found to download" unless chrome_date_range(int).present?
    youtube_history = chrome_date_range(int)
    #@logger.info("found #{youtube_history.count } youtube url(s) for days between #{int.days.ago.strftime("%A, %d %b %Y")} and #{Date.today.strftime("%A, %d %b %Y")}")
    youtube_history.each { |url| youtube_subtitles(url) }
  end

  # Create a filepath array saving the returned value of the sub_dir method
  # invocation in a variable called subtitle_path which is an Array. We then
  # loop over the Array creating the String variable `name' which is the
  # basename and the String variable `type' which is the extension type. (json,
  # vtt). A hash is lastly created using the `name' variable to create a key
  # and the `type' variable to create two nested keys, the values of which are
  # the `file' block variable which is the absolute file path.

  def filepaths
    binding.pry
    subtitle_path = sub_dir(@root_dir)
    if subtitle_path.present?
      subtitle_path.each do |file|
        begin
          name = File.basename(file).split(/\./)[0]
          type = File.extname(file).split(/\./)[1]
          @filepaths[name][type] = file
        rescue Exception => e
          puts "#{__FILE__}:#{__LINE__}:in #{__method__}: #{e}"
        end
      end
      @filepaths.reject! { |k,v| v.count != 2 }
      raise "no files pass validation." unless @filepaths.present?
      filepaths = @filepaths.deep_symbolize_keys
      return filepaths
    else
      #@logger.error("#{__FILE__}:#{__LINE__}:in #{__method__}: There are #{subtitle_path.count} downloaded subtitles")
    end
  end

end

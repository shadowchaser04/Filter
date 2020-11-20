#!/usr/bin/env ruby
require File.expand_path('../../config/environment', __FILE__)
require 'pry'
require 'json'
require 'logger'
require_relative 'youtube_history'

# TODO: denominations of the categories turned into percentages
# TODO: support for safari.
# TODO: access history.db while browser is open.
# TODO: close browser if unable to find a way to run and access history.
# TODO: logging.
# TODO: how to group result topics without explicit naming.
# TODO: add optinal words to the ten keys?
# TODO: documentation
# posative and negative sentiment
# mma, boxing,
# visual, auditory, kinetic
# {{{1 format
#------------------------------------------------------------------------------
def div
  puts "-"*50
end

def blue(color)
  "\e[34m#{color}\e[0m"
end
# }}}
# {{{1 logger
#------------------------------------------------------------------------------
# log app status's
module Logging
  def logger_output(choice_of_output)
      Logger.new(choice_of_output,
      level: Logger::INFO,
      progname: 'youtube',
      datetime_format: '%Y-%m-%d %H:%M:%S',
      formatter: proc do |severity, datetime, progname, msg|
        "[#{blue(progname)}][#{datetime}], #{severity}: #{msg}\n"
      end
    )
  end
end


include Logging

# create a instance of logger for output to the sdtout
logger = logger_output(STDOUT)

# log file.
log_to_logfile = logger_output("logfile.log")

# logger = STDOUT
logger.info("Program started...")

# }}}
# {{{1 methods
#------------------------------------------------------------------------------
def database_exists?
  ActiveRecord::Base.connection
rescue ActiveRecord::NoDatabaseError
  false
else
  true
end

def syllable_count(word)
  word.downcase!
  return 1 if word.length <= 3
  word.sub!(/(?:[^laeiouy]es|ed|[^laeiouy]e)$/, '')
  word.sub!(/^y/, '')
  word.scan(/[aeiouy]{1,2}/).size
end

# Counts each occurence of the word by the group_by method and hashes the result.
class Array
  def count_and_hash
    self.group_by(&:itself).transform_values(&:count).sort_by{|k, v| v}.reverse.to_h
  end
end

# snake case a constant
class String
  def underscore
    self.gsub(/::/, '/').
    gsub(/([A-Z]+)([A-Z][a-z])/,'\1_\2').
    gsub(/([a-z\d])([A-Z])/,'\1_\2').
    tr("-", "_").
    downcase
  end
end

# read each line of the subtitles and remove time stands and color stamps.
def read_file(arg)
  sanatised = []
  File.open(arg).each do |line|
    line.gsub!(/<[^>]*>/, "")
    line.gsub!(/(__)/, '')
    sanatised << line.gsub(/([^\w\s]|([0-9]|\:|\.))/, "").downcase
  end
  # remove dup lines with uniq then clean up formatting.
  aa = sanatised.uniq.join.split(" ")
  # reject any nil or empty strings
  aa.reject { |item| item.nil? || item == '  ' || item == ' ' || item == '\n' || item == ' \n' }
end

# test whether then db returns true or false on the user or kicks an error.
def has_db_been_populated
  begin
    User.all.present?
  rescue ActiveRecord::StatementInvalid => e
    puts "#{e}"
    puts "Check the datbase has been created by running. Rake subtitle:full_build"
    log_to_logfile.error("Program Closed: Database does not exist.")
    exit
  end
end

# eager load the models keep it outside the loop so its only called once.
# For Rails5 models are now subclasses of ApplicationRecord so to get the list
# of all models in your app you do:
def load_models
  Rails.application.eager_load!
  return ApplicationRecord.descendants.collect { |type| type.name }
end

private def nested_hash_default
  Hash.new { |h,k| h[k] = Hash.new(0) }
end

private def hash_nested_array
  Hash.new { |h,k| h[k] = [] }
end

# }}}
# {{{1 Class: SubtitleDownloader

class SubtitleDownloader

  attr_accessor :topics_values_summed, :paragraph, :paragraph_dataset

  include Logging

  def initialize
    @filepaths = Hash.new {|h,k| h[k] = Hash.new }
    @paragraph_dataset = Hash.new {|h,k| h[k] = Hash.new }
    @subtitles = Hash.new
    @topics_values_summed = nested_hash_default
    @paragraph = Hash.new {|h,k| h[k] = Hash.new {|hash, key| hash[key] = [] }}
    @added_paragraph_dataset = Hash.new {|h,k| h[k] = Hash.new {|hash,key| hash[key] = []} }
    @logger = logger_output(STDOUT)
    @root_dir = "/Users/shadowchaser/Downloads/Youtube_Subtitles/Subs"
    @ignore_files = ["Blacklist", "User", "YoutubeResult", "Chrome", "Subtitle"]
  end

  # Uses youtube-dl to download subtitles and json file to.
  # ~/Downloads/Youtube/subs/
  def youtube_subtitles(address)
      system("youtube-dl --write-auto-sub --sub-format best --no-playlist --sub-lang en --skip-download --write-info-json \'#{address}\'")
  end

  # Creates and array of absolute filepaths.
  def sub_dir(directory_location)
    raise ArgumentError, "Argument must be a String" unless directory_location.class == String
    Dir.glob(directory_location + "/**/*").select{ |f| File.file? f }
  end

  # Subtract the words returned from the Blacklist words_array from the words array.
  def remove_blacklisted_words_from(words_array)
    raise ArgumentError, "Argument must be a Array" unless words_array.class == Array
    (words_array - Blacklist.where(word: words_array).pluck(:word))
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
    youtube_history.each { |url| youtube_subtitles(url) }
  end

  # Create a filepath array saving the returned value of the sub_dir method
  # invocation in a variable called subtitle_path which is an Array. We then
  # loop over the Array creating the String variable `name' which is the
  # basename and the String variable `type' which is the extension type. (json,
  # vtt). A hash is lastly created using the `name' variable to create a key
  # and the `type' variable to create two nested keys, the values of which are
  # the `file' block variable which is the absolute file path.

  def subtitles_file_path
    subtitle_path = sub_dir(@root_dir)
    if subtitle_path.present?
      subtitle_path.each do |file|
        begin
          name = File.basename(file).split(/\./)[0]
          type = File.extname(file).split(/\./)[1]
          @filepaths[name][type.to_sym] = file
        rescue Exception => e
          puts "#{__FILE__}:#{__LINE__}:in #{__method__}: #{e}"
        end
      end
      @filepaths.reject! { |k,v| v.count != 2 }
      raise "no files pass validation." unless @filepaths.present?
      return @filepaths
    else
      @logger.error("#{__FILE__}:#{__LINE__}:in #{__method__}: There are #{subtitle_path.count} downloaded subtitles")
    end
  end

  # Loop over the filepaths hash creating two block variables `key' and
  # `file_hash'. file_hash is a Hash that contains two keys (json, vtt).
  # Create the subtitles_array by saving the returned value of the read_file
  # method invocation in a variable called subtitles_array.
  # Lastly create the @subtitles Hash using the title to create a key and the
  # subtitles_array as the value.

  def create_subtitles_array(filepaths_hash)
    raise ArgumentError, "argument must be a Hash" unless filepaths_hash.class == Hash
    filepaths_hash.each do |title, file_hash|
      subtitles_array = read_file(file_hash[:vtt])
      @subtitles[title] = subtitles_array
    end
    return @subtitles
  end

  # create a Hash. Key: video title, Value: subtitles Array.
  def build_subtitles_hash
      subtitles = create_subtitles_array(subtitles_file_path)
      return subtitles
  end

  # Hash the subtitles_array removing all blacklisted words. Take the top 10
  # counted keys. Key:k, Loop over the keys.
  # Loop over the subtitle_array making a tupal of the indices and the word then
  # use the group_by specifying which index of the iterator to use to form the
  # primary key of the grouped_by hash. Pass in the Key:k flatten and map
  # only the integers.
  # Paragraphs are formed using the indices in sub_ints each represent the
  # position of the Key:k. 50 words are then found proceeding and proceeding
  # the indices and joined in to a paragraph.

  def create_paragraphs(downloaded_subs, int=10)
    raise ArgumentError, "argument must be a Hash" unless downloaded_subs.class == Hash
    raise ArgumentError, "argument must be a Integer" unless int.class == Integer
    downloaded_subs.each do |key, subtitle_array|
      top_count_hash = remove_blacklisted_words_from(subtitle_array).count_and_hash.first(int).to_h
      top_count_hash.keys.each do |k|
        subs = subtitle_array.each_with_index.map {|w,i| [w,i] }.group_by {|i| i[0] }
        subs_ints = subs[k].flatten.map {|x| Integer(x) rescue nil }.compact
        subs_ints.map! {|i| pre = i - 50; pro = i + 50; pre = i if pre < 0; subtitle_array[pre..pro].join(" ") }
        subs_ints.each {|paragraph| (@paragraph[key][k]||[]) << paragraph }
      end
    end
  end

  # The build_paragraphs method excepts an Integer argument. How many keys you
  # want created. Present? checks if there is a return value present using the
  # ternary operator which evaluates true or false. True: return paragraphs or
  # False: raise an error.

  def build_paragraphs(int)
    raise ArgumentError, "argument must be a Integer" unless int.class == Integer
    paragraphs = create_paragraphs(build_subtitles_hash,int)
    paragraphs.present? ? (return paragraphs) : (raise "#{__FILE__}:#{__LINE__}:in #{__method__}: unable to create paragraphs_hash")
  end

  # Pluck all the words from the model-dataset creating an array. Loop over the
  # array keeping only the words that are able to be split into an array using
  # split then are over the count of one. This rejects single words and keeps
  # only sentences. Join all the paragraphs into one long string and scan the
  # string for the sentence, returning each occurrence as an array.
  # Lastly return the hash results.

  def create_dataset_sentences(paragraph)
    raise ArgumentError, "Argument must be a Array" unless paragraph.class == Array
    subs = paragraph.join.split.count_and_hash
    sentence_hash = nested_hash_default

    load_models.each do |dataset|
      unless @ignore_files.include?(dataset)
        begin
          ds = dataset.constantize.pluck(:word).keep_if {|x| x.split.count > 1 }
          ds.each do |sentence|
          if paragraph.join.scan(/#{sentence}/).present?
            sentence_hash[dataset.underscore.to_sym][sentence.to_sym] = paragraph.join.scan(/#{sentence}/).count
          end
        end
        rescue Exception => error
          raise "#{__FILE__}:#{__LINE__}:in #{__method__}: #{error}"
        end
      end
    end
    return sentence_hash
  end

  # Pass in an array. Hash the array into a counted words hash and make an
  # array of just the keys. This is so the word is only queried once on the
  # call to the database. Pluck the words it finds. Lastly loop over the words
  # using the model name as the primarily key and the word as the secondary key.
  # The word is then searched for in the counted words hash returning its count
  # value.
  # NOTE: The subs.keys passed to the where searches all keys at once which is fast
  # as the words have been counted. If found we know how many occurrences there are.

  def create_dataset_words(paragraph)
    raise ArgumentError, "Argument must be a Array" unless paragraph.class == Array
    subs = paragraph.join.split.count_and_hash
    words_hash = nested_hash_default

    load_models.each do |dataset|
      unless @ignore_files.include?(dataset)
        if dataset.constantize.where(word: subs.keys).present?
          found_words = dataset.constantize.where(word: subs.keys).pluck(:word)
          found_words.each {|word| words_hash[dataset.underscore.to_sym][word.to_sym] = subs[word] }
        end
      end
    end
    return words_hash
  end

  # Loop over the paragraphs_hash which is a youtube video title and hash of
  # keys with corresponding paragraphs. Loop over the hash which produces a key
  # and an array of paragraphs. Pass the paragraphs to the sentences and words
  # then merge them into one hash. Create a count of the top ten words counted
  # from the paragraphs. Add all to the paragraphs hash.

  def build_paragraph_datasets(paragraphs_hash)
    raise ArgumentError, "Argument must be a Hash" unless paragraphs_hash.class == Hash
    paragraphs_hash.each do |title, hash_keys|
      hash_keys.each do |key, para|
        sentence = create_dataset_sentences(para)
        words = create_dataset_words(para)
        sentence.each {|k,v| words[k] = v }
        topten = remove_blacklisted_words_from(para.join.split).count_and_hash.first(10).to_h.symbolize_keys
        @paragraph_dataset[title][key] = [para,topten,words]
      end
    end
  end

  # Two layered hash. A hash with hash - values. Results are pushed to the
  # topics_values_summed hash. Value[-1] is the last item which is always the topics hash.

  def sum_topic_values(multiple_video_hash)
    raise ArgumentError, "Argument must be a Hash" unless multiple_video_hash.class == Hash
    multiple_video_hash.each do |title,ten_key_hash|
      ten_key_hash.each do |key, value|
        value[-1].each {|k,v| @topics_values_summed[title.to_sym][k] += v.values.sum }
      end
    end
  end

  # Create a topten counted word hash of each youtube video.

  def topten
    if @subtitles.present?
      hashy = Hash.new {|h,k| h[k] = Hash.new }
      @subtitles.each {|k, subs| hashy[k] = remove_blacklisted_words_from(subs).count_and_hash.first(10).to_h }
    else
      @logger.error("Error: There are #{@subtitles.count} subtitles available in #{__method__}")
    end
    return hashy
  end

  # Loop over each youtube video title and its paragraphs.

  def build_database(added_paragraph_dataset)
    added_paragraph_dataset.each do |k,para|

      # Key:title, NestedKey:filetype, Value: absolute path.
      file = @filepaths[k][:json]

      # data is the video json file for the subtitles.
      data = JSON.parse(File.read(file))
      @logger.info("Creating: #{k} for User: #{data['uploader']}.")

      yt_user = User.find_or_create_by(uploader: data['uploader'], channel_id: data['channel_id'])
      re = yt_user.youtube_results.find_or_create_by(title: data['title'])
      re.update(duration: data['duration'], meta_data: {total: @topics_values_summed[k], topten: topten[k]})
      re.subtitles.find_or_create_by(title:data['title'], paragraph:para)
    end
  end

end

#}}}
# {{{1 test connection
#------------------------------------------------------------------------------
log_to_logfile.error("Program Close: Database does not exist.") unless database_exists?
exit unless database_exists?

# test whether then db returns true or false on the user or kicks an error.
# if not this will exit the program.
has_db_been_populated
# }}}
# {{{1 remove old directories
#------------------------------------------------------------------------------
# root directory
root_dir = "/Users/shadowchaser/Downloads/Youtube_Subtitles/Subs"

# remove the directory so its empty
FileUtils.remove_dir(root_dir) if Dir.exist?(root_dir)
logger.info("removed #{root_dir}") if !Dir.exist?(root_dir)

# remake the directory so its empty
FileUtils.mkdir(root_dir) if !Dir.exist?(root_dir)
logger.info("re-created #{root_dir}") if Dir.exist?(root_dir)

# }}}
#{{{1 load datasets
# Eager loads the rails models. If datasets are not present exit and log
# otherwise print the count to screen.
if load_models.present?
  logger.info("found #{load_models.count} datasets")
else
  log_to_logfile.error("#{load_models.count} datasets were found.")
  exit
end
#}}}
#{{{1 chrome History

# include the module youtube_history.
include YoutubeHistory

if Chrome.present?

  # make a connection to the chrome db
  connect_to_chrome

  # create a instance of Url
  youtube = Url.new

  # create a hash of just the youtube results from the chrome history.
  youtube_urls_hash = youtube.youtube_urls_hash

  # re-establish_connection to rails db
  connect_to_rails

  # populate chrome model
  unless youtube_urls_hash.empty?
    youtube_urls_hash.each do |key, value|

      # create or find the initial object based on title and url
      youtube = Chrome.find_or_create_by(title: key, url: value[:url])
      if youtube.last_visit == nil
        youtube.update(visit_count: value[:visit_count] , last_visit: value[:last_visit])
      # update the Chrome ActiveRecord if there last_visit has changed.
      elsif youtube.last_visit < value[:last_visit]
        youtube.update(visit_count: value[:visit_count] , last_visit: value[:last_visit])
      end

    end
  end
else
  raise "Chrome model does not exist"
  exit
end

# exit if there are no chrome records.
unless Chrome.any?
  @logger.error("DownloadSubtitlesError: Please check Chrome Model exists")
  exit
end

#}}}
# {{{1 create subtitle paragraphs

# create an instance of subtitles downloader.
downloader = SubtitleDownloader.new

# Download the subtitles providing an argument how many days ago.
downloader.download_subtitles(1)

# Build the Subtitles Hash. key: title of video. Value: subtitles Array.
downloader.build_subtitles_hash

# Build the Paragraphs. Takes an Arg how many paragraph keys you want created.
# All occurrences of the key will then be found, creating the paragraph's.
# Key: video title, Value: value array. The values are the paragraphs.
downloader.build_paragraphs(3)

# build the dataset information for the paragraphs.
downloader.build_paragraph_datasets(downloader.paragraph)

# paragraph_dataset is the returned setter hash from build_paragraph_datasets.
downloader.sum_topic_values(downloader.paragraph_dataset)

# build the datbase entries. paragraph_dataset is the returned setter hash from
# build_paragraph_datasets.
downloader.build_database(downloader.paragraph_dataset)

#}}}
# {{{1 total Users

# Create a hash with a defualt value of 0
result_hash = Hash.new {|h,k| h[k] = Hash.new(0) }

# iterate over each User tallying the results of all the youtube_results.
User.all.each do |item|

  # reset the accumulated_duration so it can be rebuilt dependent on any
  # changes to its size.
  item[:accumulated_duration] = 0

  # iterate over each assosiaction record belonging to the user.
  item.youtube_results.each do |obj|

    # retrive the json hash - :meta_data and iterate over each k,v pair adding
    # the key and counting the value to the result hash.
    obj[:meta_data]['total'].each {|k,v| result_hash["#{item[:uploader]}"][k] += v }

    # accumulate each of the durations.
    item[:accumulated_duration] += obj[:duration]
  end

  # add the count to the video_count attribute and update the last updated
  # accumulated_duration attribute. Lastly re add the hash to accumulator.
  item.update(video_count: item.youtube_results.count, accumulator_last_update: Time.now, accumulator: result_hash["#{item[:uploader]}"])
end
# }}}

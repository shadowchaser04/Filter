#!/usr/bin/env ruby
require File.expand_path('../../config/environment', __FILE__)
require 'pry'
require 'json'
require 'logger'

# TODO: add error handling. classes
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

  attr_accessor :paragraph, :topics_values_summed

  include Logging

  def initialize
    @filepaths = Hash.new {|h,k| h[k] = Hash.new }
    @subtitles = Hash.new
    @topics_values_summed = nested_hash_default
    @paragraph = Hash.new {|h,k| h[k] = Hash.new {|hash, key| hash[key] = [] }}
    @added_paragraph_dataset = Hash.new {|h,k| h[k] = Hash.new {|hash,key| hash[key] = []} }
    @logger = logger_output(STDOUT)
    @root_dir = "/Users/shadowchaser/Downloads/Youtube_Subtitles/Subs"
  end

  # Uses youtube-dl's auto sub generate downloader. downloads to ~/Downloads/Youtube
  def youtube_subtitles(address)
      system("youtube-dl --write-auto-sub --sub-format best --no-playlist --sub-lang en --skip-download --write-info-json \'#{address}\'")
  end

  # Creates and array of absolute filepaths.
  def sub_dir(directory_location)
    raise ArgumentError, "Argument must be a String" unless directory_location.class == String
    Dir.glob(directory_location + "/**/*").select{ |f| File.file? f }
  end

  # Subtract the words returned from the Blacklist call from the words_array.
  def remove_blacklisted_words_from(words_array)
    raise ArgumentError, "Argument must be a Array" unless words_array.class == Array
    (words_array - Blacklist.where(word: words_array).pluck(:word))
  end

  # Pass in a date range of days to search backwards in the chrome history.
  def chrome_date_range(date_range=1)
    raise ArgumentError, "Argument must be a Integer" unless date_range.class == Integer
    Chrome.where(:last_visit => date_range.days.ago..date_range.days.from_now).pluck(:url)
  end

  # loop over each record downloading them to the ~/downloads/subs/*
  def download_subtitles
    chrome_date_range(1).each {|url| begin; youtube_subtitles(url); rescue Exception => e; puts "#{e}";end }
  end

  # Create a filepath array. Remove the extension from the files to create a key
  # Strip the filetype .json and .vtt and create a key, Add the file to the value.
  def subtitles_file_path
    subtitle_path = sub_dir(@root_dir)
    raise "FilePath found 0 files." unless subtitle_path.present?
      subtitle_path.each do |file|
        name = File.basename(file).split(/\./)[0]
        type = File.extname(file).split(/\./)[1]
        @filepaths[name][type.to_sym] = file
      end
      @filepaths.reject! { |k,v| v.count != 2 }
      return @filepaths
  end

  # Loop over the filepaths. Create a Key: title, Value: subtitles array.
  def create_subtitles_array(path_hash)
    raise ArgumentError, "argument must be a Hash" unless path_hash.class == Hash
    path_hash.each {|key, file| @subtitles[key] = read_file(file[:vtt]) if file[:vtt] }
    return @subtitles
  end

  def create_paragraphs(downloaded_subs)
    raise ArgumentError, "argument must be a Hash" unless downloaded_subs.class == Hash
    if downloaded_subs.present?
      downloaded_subs.each do |key, sublist|
        top_count_hash = remove_blacklisted_words_from(sublist).count_and_hash.first(10).to_h
        top_count_hash.keys.each do |k|
          # group_by groups all the words and there index's
          # This creates a key and an array. The array contains all
          # occurrence of the word and its index position.
          subs = sublist.each_with_index.map {|w,i| [w,i] }.group_by {|i| i[0] }

          # k is queried, if found it returns an array which is flattened. it is
          # mapped returning only the integers which are the index positions of
          # the words.
          subs_ints = subs["#{k}"].flatten.map {|x| Integer(x) rescue nil }.compact

          # subs_ints is remapped permanently altering the array. First it creates a
          # range of 50 words before and after i. Which is its index position. These
          # are then joined into the paragraph.
          subs_ints.map! {|i| pre = i - 50; pro = i + 50; pre = i if pre < 0; sublist[pre..pro].join(" ") }
          subs_ints.each {|paragraph| (@paragraph[key][k]||[]) << paragraph }
        end
      end
    end
  end

  # Two layerd hash. Hash with hash - values. Results are pushed to the
  # topics_values_summed hash accessed through the attr_accessor.
  def sum_topic_values(multiple_video_hash)
    raise ArgumentError, "Argument must be a Hash" unless multiple_video_hash.class == Hash
    multiple_video_hash.each do |title,ten_key_hash|
      ten_key_hash.each do |key, value|
        # value[-1] is the last item which is always the rhash - topics.
        value[-1].each {|k,v| @topics_values_summed[title][k] += v.values.sum }
      end
    end
  end

  # Create a topten counted word hash of each youtube video.
  def topten
    raise "There are no Subtitles present" unless @subtitles.present?
    hashy = Hash.new {|h,k| h[k] = Hash.new }
    @subtitles.each {|k, subs| hashy[k] = remove_blacklisted_words_from(subs).count_and_hash.first(10).to_h }
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
#{{{1 Chrome Entries
unless Chrome.present? && Chrome.any?
  @logger.error("DownloadSubtitlesError: Please check Chrome Model exists and contains records.")
end
#}}}
# {{{1 create subtitles words array
# create an instance of subtitles downloader.
downloader = SubtitleDownloader.new

# Download the subtitles.
downloader.download_subtitles

# Create a hash of subtitle file paths.
# Key: file name, Value: Hash - K:filetype V:fullpath
file_path_hash = downloader.subtitles_file_path
logger.info("Downloaded #{file_path_hash.keys.count} subtitles") if file_path_hash.present?

# Pass in the return value of the file_path_hash. This returns a hash.
# Key: title, Value: Array of subtitle words.
downloaded_subs = downloader.create_subtitles_array(file_path_hash)
logger.info("Created #{downloaded_subs.count} subtitles words arrays.") if downloaded_subs.present?

# }}}
# {{{1 create paragraphs and topics
# Create a hash
# Key: video title, Value: value arrays. The values are the paragraphs.
downloader.create_paragraphs(downloaded_subs)

paragraph_dataset = Hash.new {|h,k| h[k] = Hash.new {|h,k| h[k] = [] }}

ignore_files = ["Blacklist", "User", "YoutubeResult", "Chrome", "Subtitle"]

# Setter: Hash
# Loop over the title and ten_key_hash, each title represents a new youtube
# video. The hash is ten keys and there corrisponding paragraphs.
downloader.paragraph.each do |title, ten_key_hash|

  # loop over the hash's 10 keys and paragraphs.
  ten_key_hash.each do |key, para|

    # create a hash each iteration round the loop.
    rhash = nested_hash_default

    # Subs joins all the paragraphs for each key and counts and hashes them.
    # this is done so when it passes the subs.keys to the datasets they are
    # only looking for each occurence of the word once. The value which is the
    # count for its corrisponding key is later added back as rhash is built.
    subs = para.join.split.count_and_hash

    load_models.each do |dataset|
      unless ignore_files.include?(dataset)

        # pluck all words from the datasets, keeping only if they are more than
        # one word long.
        ds = dataset.constantize.pluck(:word).keep_if {|x| x.split.count > 1 }

        # scan each paragraph string for the sentence.
        ds.each {|sentence| rhash[dataset.underscore][sentence] = para.join.scan(/#{sentence}/).count if para.join.scan(/#{sentence}/).present? }

        if dataset.constantize.where(word: subs.keys).present?
          # pass in the keys and pluck the word from the returned collection.
          # then loop over each of the words creating the hash
          # Key:dataset, SecondaryKey:found word, Value:occurrences of the word.
          found_words = dataset.constantize.where(word: subs.keys).pluck(:word)
          found_words.each {|word| rhash[dataset.underscore.to_sym][word.to_sym] = subs[word] }
        end
      end
    end

    # create topten count of words. Add the paragraphs topten and topics.
    # Flatten out the additional created array.
    #topten = remove_blacklisted_words_from(para.join.split).count_and_hash.first(10).to_h.symbolize_keys
    # re-add the topten
    (paragraph_dataset[title][key]||[]) << [para,rhash]
    paragraph_dataset[title].transform_values!(&:flatten)

  end
end

#}}}
#{{{1 sum topics

# Sum each value of the nested hash array. returning @topics_values_summed.
# This is used in the build_database method.
downloader.sum_topic_values(paragraph_dataset)

#}}}
#{{{1 build database

# build the datbase entries.
downloader.build_database(paragraph_dataset)

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

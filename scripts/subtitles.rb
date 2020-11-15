#!/usr/bin/env ruby
require File.expand_path('../../config/environment', __FILE__)
require 'pry'
require 'json'
require 'logger'

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

class Array
  # Counts each occurence of the word by the group_by method and hashes the result.
  def count_and_hash
    self.group_by(&:itself).transform_values(&:count).sort_by{|k, v| v}.reverse.to_h.symbolize_keys
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

# Uses youtube-dl's auto sub generate downloader. downloads to ~/Downloads/Youtube
def youtube_subtitles(address)
    system("youtube-dl --write-auto-sub --sub-format best --no-playlist --sub-lang en --skip-download --write-info-json \'#{address}\'")
end

# Creates and array of absolute filepaths.
def sub_dir(directory_location)
    Dir.glob(directory_location + "/**/*").select{ |f| File.file? f }
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

def load_models
  # eager load the models keep it outside the loop so its only called once.
  Rails.application.eager_load!

  # For Rails5 models are now subclasses of ApplicationRecord so to get the list
  # of all models in your app you do:
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

  attr_accessor :paragraph, :added_paragraph_dataset, :topics_values_summed

  include Logging

  def initialize
    @filepaths = Hash.new {|h,k| h[k] = Hash.new }
    @subtitles = hash_nested_array
    @topics_values_summed = nested_hash_default
    @paragraph = Hash.new {|h,k| h[k] = Hash.new {|hash, key| hash[key] = [] }}
    @added_paragraph_dataset = Hash.new {|h,k| h[k] = Hash.new {|hash,key| hash[key] = []} }
    @logger = logger_output(STDOUT)
    # NOTE: any models none dataset
    @ignore_files = ["Blacklist", "User", "YoutubeResult", "Chrome", "Subtitle"]
  end

  # check the existence of the model in the db and that there are any records.
  # loop over each record downloading them to the ~/downloads/subs/*
  def download_subtitles(date_range=1)
    if Chrome.exists? && Chrome.any?
      raise ArgumentError, "argument must be a Integer" unless date_range.class == Integer
        chrome = Chrome.where(:last_visit => date_range.days.ago..date_range.days.from_now).pluck(:url)
        @logger.info("Found #{chrome.count} chrome records for the period #{date_range.days.ago.strftime("%A, %d %b %Y ")} untill #{Time.now.strftime("%A, %d %b %Y ")}")
        chrome.each {|url| begin; youtube_subtitles(url); rescue Exception => e; puts "#{e}";end }
    else
      @logger.error("DownloadSubtitlesError: Please check Chrome Model exists and contains records.")
      exit
    end
  end

  # Create a filepath array subtitle_path. Loop over the file paths creating a
  # hash. Remove the extension from the files to create a key and add each .json
  # and .vtt to the keys value array, finally removing any keys that the values
  # do not contain both of the .json and .vtt files for.
  def subtitles_file_path(directory)
    subtitle_path = sub_dir(directory)
    if subtitle_path.present?
      subtitle_path.each do |file|
        f = File.basename(file).split(/\./)[0]
        type = File.extname(file).split(/\./)[1]
        @filepaths[f][type.to_sym] = file
      end
      @filepaths.reject! { |k,v| v.count != 2 }
      return @filepaths
    else
      @logger.error("SubtitlesFilepathError: there are #{subtitle_path.count} files downloded")
      exit
    end
  end

  # Loop over the files finding the subtitles by there filetype .vtt
  # create an array of subtitle words with this file and add the array to the
  # hash using the original key. Then flatten the values array because it has
  # an additional nested level that is unnecessary.
  def create_subtitles_array(path_hash)
    raise ArgumentError, "argument must be a Hash" unless path_hash.class == Hash
    path_hash.each do |key, file|
      (@subtitles[key]||[]) << read_file(file[:vtt]) if file[:vtt]
      @subtitles.transform_values! {|v| v.flatten } if file[:vtt]
    end
    return @subtitles
  end

  # Pass in the sublist array to the Where returning an array of blacklisted
  # words then subtract them from the sublist.
  # Group the words by themselves then count the words, sort and turn into a hash
  def create_paragraphs(downloaded_subs)
    downloaded_subs.each do |key, sublist|
      top_count_hash = remove_blacklisted_words_from(sublist).count_and_hash.first(10).to_h

      top_count_hash.keys.each do |k|
        # loops over the top ten found words, group_by groups all the nested array words
        # and there index's. This creates a key and an array. The array contains all
        # occurrence of the word and its index position.
        subs = sublist.each_with_index.map {|w,i| [w,i] }.group_by {|i| i[0] }

        # k is queried in the hash, if found it returns an array which is flattened.
        # it is mapped returning only the integers which are the index positions of
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

  def remove_blacklisted_words_from(words_array)
    (words_array - Blacklist.where(word: words_array).pluck(:word))
  end

  # loop over the hashy 10 keys and paragraphs.
  def paragraph_datasets(name, hashy)
    hashy.each do |key, para|
      rhash = nested_hash_default
      subs = para.join.split.count_and_hash

      load_models.each do |dataset|
        unless @ignore_files.include?(dataset)
          ds = dataset.constantize.pluck(:word).keep_if {|x| x.split.count > 1 }
          ds.each {|x| rhash[dataset.underscore][x] = para.join.scan(/#{x}/).count if para.join.scan(/#{x}/).present? }
          if dataset.constantize.where(word: subs.keys).present?
            found_words = dataset.constantize.where(word: subs.keys).pluck(:word)
            found_words.each {|word| rhash[dataset.underscore][word.to_sym] = subs[word.to_sym] }
          end
        end
      end
      # topten list after removing blacklist
      topten = remove_blacklisted_words_from(subs.keys).count_and_hash.first(10).to_h

      # iterate over the paragraphs so as to avoid nesting array.
      (@added_paragraph_dataset[name][key]||[]) << [para,topten,rhash]

      # remove additional nested array layer.
      @added_paragraph_dataset[name].transform_values!(&:flatten)
    end
  end

  # two layerd hash. Hash with hash - values. results are pushed to the
  # topics_counted hash accessed through the attr_accessor.
  def sum_topic_values(hashy)
    hashy.each do |title,v|
      v.each do |key, value|
        value[-1].each {|k,v| @topics_values_summed[title][k] += v.values.sum }
      end
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
# {{{1 create subtitles words array
# create an instance of subtitles downloader.
downloader = SubtitleDownloader.new

# Download the subtitles. Arg = Int. How many days backwards in the history.
downloader.download_subtitles(1)

# Create a hash of subtitle file paths.
file_path_hash = downloader.subtitles_file_path(root_dir)

# Pass in a hash the key being the spliced file name. The value is an array of
# absoulute file paths to the json and vtt files, this returns a hash. The key
# is named after the title and the array values are the subtitle words array.
downloaded_subs = downloader.create_subtitles_array(file_path_hash)

# Create a hash that contains the video titles as the keys, and nested hashes as
# value arrays. The values are the paragraphs.
downloader.create_paragraphs(downloaded_subs)

# Setter Hash: pass in the title and hash from paragraphs, which contains 10 keys
# with corrisponding paragraphs to the paragraph_datasets method. This will
# create the dataset topic information and the topten counted words.
downloader.paragraph.each {|k,h| downloader.paragraph_datasets(k,h) }

# Setter Hash: paragraphs, datasets topics and topten from the paragraph_datasets
topics_hash = downloader.added_paragraph_dataset

# Sum each value of the nested hash array. returning topics_values_summed.
downloader.sum_topic_values(topics_hash)

# Setter Hash: final hash with paragraphs topics and topten counted words.
topics = downloader.topics_values_summed

topics.each do |title, value|

  file = file_path_hash[title][:json]
  data = JSON.parse(File.read(file))

  # find the user and make the assosiation then update meta and duration.
  yt_user = User.find_or_create_by(uploader: data['uploader'], channel_id: data['channel_id'])
  re = yt_user.youtube_results.find_or_create_by(title: data['title'])
  re.update(duration: data['duration'], meta_data: {total: topics[title]})
  # NOTE: find might not be finding if the record exists.
  re.subtitles.find_or_create_by(title:title, paragraph: topics[title])

end
# }}}


#!/usr/bin/env ruby
require File.expand_path('../../config/environment', __FILE__)
require 'pry'
require 'json'
require 'logger'

# TODO: down database and models.

# get todays date
# do i write to file or db as an assosiated record to each video?

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
  def count_and_hash(result=10)
    self.group_by(&:itself).transform_values(&:count).sort_by{|k, v| v}.reverse.first(result).to_h.symbolize_keys
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
    system("youtube-dl --write-auto-sub --sub-format best --sub-lang en --skip-download --write-info-json \'#{address}\'")
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

private def nested_hash
  Hash.new { |h,k| h[k] = Hash.new(0) }
end

private def hash_nested_array
  Hash.new { |h,k| h[k] = [] }
end

# }}}
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
# {{{1 Class SubtitleDownloader

class SubtitleDownloader

  def initialize
    @filepaths = hash_nested_array
    @subtitles = hash_nested_array
  end

  # check the existence of the model in the db and that threr are any records.
  # loop over each record downloading them to the downloads/subs/*
  def download_subtitles
    if Chrome.exists? && Chrome.any?
      chrome = Chrome.where(:last_visit => 1.days.ago..1.days.from_now).pluck(:url)
      chrome.each {|url| begin; youtube_subtitles(url); rescue Exception => e; puts "#{e}";end }
    else
      #logger.error("DownloadSubtitlesError: Please check Chrome Model exists and contains records.")
      puts "DownloadsSubtitleError"
      exit
    end
  end

  # add the file to the hash array.
  def subtitles_file_path(directory)
    # create the filepaths.
    subtitle_path = sub_dir(directory)

    # loop over the file paths to organise them.
    # create a key by removing the extention and splicing the basename.
    subtitle_path.each {|file| f = File.basename(file).split(/\./)[0]; (@filepaths[f]||[]) << file }

    # remove any array values that dont have both a json and a vtt file.
    @filepaths.reject! { |k,v| v.count != 2 }
    return @filepaths
  end

  def create_subtitles_array(path_hash)
    # loop over the file path hash.
    path_hash.each do |key, files|

      # loop over the array values, two files .json and .vtt
      files.each do |file|

        # find the subtitles by there filetype.
        if File.extname(file.split("/")[-1]) =~ /.vtt/
          # create an array of subtitle words then add the subtitles to the hash.
          (@subtitles[key]||[]) << read_file(file)

          # flatten the value array.
          @subtitles.transform_values! {|value_array| value_array.flatten }
        end

      end
    end

    return @subtitles
  end

end

#}}}
# {{{1 create subtitles words array

# create an instance of subtitles downloader.
downloader = SubtitleDownloader.new

# download the subtitles.
downloader.download_subtitles

# create a hash of subtitle file paths.
file_path_hash = downloader.subtitles_file_path(root_dir)

# pass in a hash the key being the spliced file name the value an array of
# absoulute file paths to the json and vtt files. returning a hash. the key
# being named after the title the array values the subtitles words array.
downloaded_subs = downloader.create_subtitles_array(file_path_hash)

# }}}
# {{{1 remove blacklist and create top ten
#------------------------------------------------------------------------------
# downloaded subs now contains the key:title and an array of the subtitles in
# sentences. The sentences will be joined and split into a single words array.
# The array of words is then passed into the Blacklist model using the where
# method which returns an array of found words as one call. This array is then
# subtracted from the original subtitles words array (sublist) removing all the
# blacklisted words.
result = Hash.new {|h,k| h[k] = Hash.new {|hash,key| hash[key] = []} }

downloaded_subs.each do |key, sublist|
  logger.info("creating paragraphs for #{key}")
  t = Time.new

  # Pass in the sublist array to the Where returning an array of badwords
  # subtracted from the sublist.
  subs = (sublist - Blacklist.where(word: sublist).pluck(:word))

  # Group the words by themselves then count the words, sort and turn into a hash
  top_count_hash = subs.count_and_hash(10)

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
    subs_ints.each {|paragraph| (result[key][k]||[]) << paragraph }
  end
  logger.info("completed #{key} in #{Time.new - t}")
end

# }}}
# {{{1 load datasets
#------------------------------------------------------------------------------
# Result paragraphs
paragraph = Hash.new { |h,k| h[k] = Hash.new {|hash,key| hash[key] = []} }

# Remove from iterating over datasets
ignore_files = ["Blacklist", "User", "YoutubeResult", "Chrome"]

#------------------------------------------------------------------------------
# Load datasets
#------------------------------------------------------------------------------
# Eager loads the rails models. If datasets are not present exit and log
# otherwise print the count to screen.
if load_models.present?
  logger.info("found #{load_models.count} datasets")
else
  log_to_logfile.error("#{load_models.count} datasets were found.")
  exit
end
# }}}


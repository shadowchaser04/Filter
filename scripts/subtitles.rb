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
  aa = sanatised.uniq
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
# {{{1 download youtube subtitles

# pass in a date range to the where method returning a collection, then pluck the
# urls returning an array.
youtube_urls = Chrome.where(:last_visit => 1.days.ago..1.days.from_now).pluck(:url)
logger.error("DownloadYoutubeSubtitlesError: no youtube videos for the period #{1.days.ago..1.days.from_now}") if youtube_urls.count == 0
exit if youtube_urls.count == 0

# loop over the youtube urls.
youtube_urls.each do |url|
  begin
    youtube_subtitles(url)
  rescue Exception => e
    puts "#{e}"
  end
end

# }}}
# {{{1 create the file path hash
# create a hash with a array as values
file_path_hash = Hash.new {|h,k| h[k] = [] }

# create the filepaths.
subtitle_path = sub_dir(root_dir)

# loop over the file paths to organise them.
subtitle_path.each do |file|

  # create a key by removing the extention and splicing the basename.
  f = File.basename(file).split(/\./)[0]

  # add the file to the hash array.
  (file_path_hash[f]||[]) << file
  logger.info("Created key #{f} in the file_path_hash")

end

# NOTE: logger needs to tell the user what has been removed.
# remove any videos that have not downloaded both subtitles and json file.
file_path_hash.reject! { |k,v| v.count != 2 }

# }}}
# {{{1 build hash containing the subtitles
#------------------------------------------------------------------------------
# create the hash for the subtitles
downloaded_subs = Hash.new { |h,k| h[k] = [] }

# loop over the file path hash.
file_path_hash.each do |key, files|

  # loop over the array values, two files .json and .vtt
  files.each do |file|

    # find the subtitles by there filetype.
    if File.extname(file.split("/")[-1]) =~ /.vtt/
      # create an array of sentences read from the subtitles.vtt file.
      subtitles = read_file(file)

      # add the subtitles to the hash.
      (downloaded_subs[key]||[]) << subtitles

      # flatten the value array.
      downloaded_subs.transform_values! {|value_array| value_array.flatten }
    end

  end
end
# }}}
# {{{1 remove blacklist
#------------------------------------------------------------------------------
result = Hash.new {|h,k| h[k] = Hash.new {|hash,key| hash[key] = []} }

downloaded_subs.each do |key, value_array|

  # create the array of words.
  sublist = value_array.join.split(" ")

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
end
binding.pry

# }}}
# {{{1 load datasets
#------------------------------------------------------------------------------
# Result paragraphs
paragraph = Hash.new { |h,k| h[k] = [] }

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
# {{{1 main
#------------------------------------------------------------------------------
# Loop over each dataset
result.each do |k, paragraph_array|
  logger.info("paragraph count is #{paragraph_array.count} for #{k}")
  # create a marker for time to log each loops rate of build.
  t=Time.now

  # Loop each individual paragraph belonging to a key.
  # The each with object takes a hash with nested hashes set to 0.
  # Iterates over a collection, passing the current element and the memo to the
  # block
  # nested_hash is a private method
  paragraph_array.flatten.each do |para|

    # create a nested hash with default value as 0
    rhash = nested_hash

    # Hash the para array and count.
    subs = para.split(" ").group_by(&:itself).transform_values(&:count).to_h

    # Rails_models are each dataset the words will be ran against.
    load_models.each do |dataset|
      unless ignore_files.include?(dataset)
        #----------------------------------------------------------------------
        # words and sentence
        #----------------------------------------------------------------------
        # Pluck all the words form the dataset. Filter out any words leaving
        # only sentences. Loop over each sentence, scanning the paragraph of
        # text (which is a string) for all occurrences of the sentence.
        ds = dataset.constantize.pluck(:word).keep_if {|x| x.split.count > 1 }
        ds.each {|x| rhash["#{dataset.underscore}"][x] = para.scan(/#{x}/).count if para.scan(/#{x}/).count >= 1 }

        # Create a array of words from the database.
        if dataset.constantize.where(word: subs.keys).present?

          # Where takes an array. In this case each key from the subs.keys
          # hash. And returns an array in one call of each found word.
          found_words = dataset.constantize.where(word: subs.keys)

          # Loop over the found words. Creating the hash per paragraph.
          found_words.each { |word| rhash["#{dataset.underscore}"][word[:word]] = subs[word[:word]] }
        end
      end
    end
    #--------------------------------------------------------------------------
    # build paragraph
    #--------------------------------------------------------------------------
    # Add the paragraph and dataset hash back into the array under its key
    (paragraph[k]||[]) << para
  end
  logger.info("Built #{k} in: #{Time.now - t}")
end
#}}}

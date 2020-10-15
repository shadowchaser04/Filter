#!/usr/bin/env ruby
require File.expand_path('../../config/environment', __FILE__)
require 'pry'
require 'json'
require 'logger'

# TODO: error handling and logging
# TODO: make an array of subscribed. automate as a cron task the reqular down
# load and updating of video subtitles.
# 1. get playlist of each subscribed video.
# 2. download the subtitles based of a date range.
# 3. loop through each sub.
# 4. update the total.
# 5. schedule via a cron task.
#------------------------------------------------------------------------------
# methods
#------------------------------------------------------------------------------
#
def database_exists?
  ActiveRecord::Base.connection
rescue ActiveRecord::NoDatabaseError
  false
else
  true
end

class TimeFormatter

    def format_time (timeElapsed)

        @timeElapsed = timeElapsed

        #find the seconds
        seconds = @timeElapsed % 60

        #find the minutes
        minutes = (@timeElapsed / 60) % 60

        #find the hours
        hours = (@timeElapsed/3600)

        #format the time

        return hours.to_s + ":" + format("%02d",minutes.to_s) + ":" + format("%02d",seconds.to_s)
    end
end

#
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
      sanatised << line.gsub(/([^\w\s]|([0-9]|\:|\.))/, "").downcase
  end
  # removedup lines with uniq then clean up formatting.
  aa = sanatised.uniq
  # reject any nil or empty strings
  aa.reject { |item| item.nil? || item == '  ' || item == ' ' || item == '\n' || item == ' \n' }
end

#
def div
  puts "-"*50
end

def blue(color)
  "\e[34m#{color}\e[0m"
end

# Uses youtube-dl's auto sub generate downloader. downloads to ~/Downloads/Youtube
def youtube_subtitles(address)
    system("youtube-dl --write-auto-sub --sub-format best --sub-lang en --skip-download --write-info-json \'#{address}\'")
end

# Creates and array of absolute filepaths.
def sub_dir(directory_location)
    Dir.glob(directory_location + "/**/*").select{ |f| File.file? f }
end

#------------------------------------------------------------------------------
# logger
#------------------------------------------------------------------------------

# log app status's
logger = Logger.new(STDOUT,
  level: Logger::INFO,
  progname: 'youtube',
  datetime_format: '%Y-%m-%d %H:%M:%S',
  formatter: proc do |severity, datetime, progname, msg|
    "[#{blue(progname)}][#{datetime}], #{severity}: #{msg}\n"
  end
)

# log file.
log_to_logfile = Logger.new("logfile.log")

# logger = STDOUT
logger.info("Program started...")

#------------------------------------------------------------------------------
# Test connection to datbase is possible
#------------------------------------------------------------------------------
log_to_logfile.error("Program Close: Database does not exist.") unless database_exists?
exit unless database_exists?
#------------------------------------------------------------------------------
# remove and remake old directory
#------------------------------------------------------------------------------
# root directory
root_dir = "/Users/shadowchaser/Downloads/Youtube_Subtitles/Subs"

# remove the directory so its empty
FileUtils.remove_dir(root_dir) if Dir.exist?(root_dir)
logger.info("removed #{root_dir}") if !Dir.exist?(root_dir)

# remake the directory so its empty
FileUtils.mkdir(root_dir) if !Dir.exist?(root_dir)
logger.info("re-created #{root_dir}") if Dir.exist?(root_dir)

#------------------------------------------------------------------------------
# take user input
#------------------------------------------------------------------------------

# loop infinitly until the youtube address passes validation the exit
while 0

  # take youtube https
  puts "please enter address:>\n"

  # get user input
  user_input = gets.chomp

  if user_input =~ /^(https|http)\:(\/\/)[w]{3}\.(youtube)\.(com)/

    # use the method youtube_playlist to download the subtitles.
    youtube_subtitles(user_input)
    break

  else
    puts "Invalid URL: please enter a valid URL"
  end

end

#------------------------------------------------------------------------------
# build datasets word and sentence and json information
#------------------------------------------------------------------------------
# create the hash for the subtiles
downloaded_subs = Hash.new { |h,k| h[k] = [] }

# hash for the json file data.
json_hash = {}

# get the subtitles back from the downloads directory
sub_path = sub_dir(root_dir)

# instead of the usual log to STDOUT log to *.log file.
log_to_logfile.info("SubPathError: Expected 2 files *.json and *.vtt. Found #{sub_path.count}.") unless sub_path.count == 2

# there should always be two
exit unless sub_path.count == 2
sub_path.each do |file|

  # find the subtitles by there filetype.
  if File.extname(file.split("/")[-1]) =~ /.vtt/

    # push the array sentences returned from the method to the hash array value.
    (downloaded_subs['sentence']||[])<< read_file(file)
    logger.info("created #{downloaded_subs['sentence'].flatten.count} sentences.") if downloaded_subs['sentence'].length > 0

    # push the array words returned from the method to the hash array value.
    (downloaded_subs['words']||[])<< read_file(file).join.split(" ")
    logger.info("created #{downloaded_subs['words'].flatten.count} words.") if downloaded_subs['words'].length > 0

  end

end

# add a subtitles table
# build the data.

#------------------------------------------------------------------------------
# remove blasklist
#------------------------------------------------------------------------------
result = Hash.new {|h,k| h[k] = [] }

# flatten out the array of arrays
sublist = downloaded_subs['words'].flatten

#NOTE: if the database has not been created this will be the first point it
#falls
# remove blacklist words from the array if they are found in the database.
subs = sublist.reject { |w| w if Blacklist.find_by(word: w) }

# group the words by themselfs then count the words, sort and turn into a hash
top_count_hash = subs.count_and_hash(10)

#------------------------------------------------------------------------------
# create paragraph
#------------------------------------------------------------------------------
top_count_hash.keys.each do |k|
  # loops over the top ten found words, group_by groups all the nested array words
  # and there index's. This creates a key and an array. The array contains all
  # occurrence of the word and its index position.
  subs = sublist.each_with_index.map {|w,i| [w,i] }.group_by {|i| i[0] }

  # k is queried in the hash, if found it returns an array which is flattened.
  # it is mapped returning only the integers which are the index positions of
  # the words.
  subs_ints = subs["#{k}"].flatten.map {|x| Integer(x) rescue nil }.compact

  # subs_ints is remapped perminantly altering the array. first it creates a
  # range of 50 words before and after i. which is its index position. These
  # are then joined into the paragraph.
  subs_ints.map! {|i| pre = i - 50; pro = i + 50; sublist[pre..pro].join(" ") }
  subs_ints.each {|paragraph| (result[:"#{k}"]||[]) << paragraph }
end

#------------------------------------------------------------------------------
# data sets and hashes for paragraphs
#------------------------------------------------------------------------------
# result paragraphs
paragraph = Hash.new { |h,k| h[k] = [] }

# remove from iterating over datasets
ignore_files = ["Blacklist", "User", "YoutubeResult"]

# eager load the models keep it outsode the loop so its only called once.
Rails.application.eager_load!

# For Rails5 models are now subclasses of ApplicationRecord so to get list of all models in your app you do:
rails_models = ApplicationRecord.descendants.collect { |type| type.name }

#------------------------------------------------------------------------------
# Dataset
#------------------------------------------------------------------------------
# loop over each dataset
result.each do |k, paragraph_array|
  logger.info("paragraph count is #{paragraph_array.count} for #{k}")

  # loop each individual paragraph belonging to a key.
  paragraph_array.flatten.each do |para|

    # create the hash each iteration.
    rhash = Hash.new { |h,k| h[k] = Hash.new(0) }

    # hash the para array and count.
    subs = para.split(" ").group_by(&:itself).transform_values(&:count).to_h

    rails_models.each do |dataset|
      logger.info("currently searching #{dataset}")
      unless ignore_files.include?(dataset)
          # create a array of words from the datbase.
        if dataset.constantize.where(word: subs.keys).present?

          # where takes an array. in this case each key from the subs.keys
          # hash. and returns an array in one call of each found word.
          found_words = dataset.constantize.where(word: subs.keys)

          # loop over the found words. creating the hash per paragraph.
          found_words.each { |word| rhash["#{dataset.underscore}"][word[:word]] = subs[word[:word]] }
        end
      end
    end
    (paragraph["#{k}"]||[]) << [para,rhash]
    puts div
  end
end
binding.pry

paragraph.each do |k,v|
  puts "#{k})\n"
  v.each_with_index do |par,i|
    puts "#{i}) #{par}\n"
  end
end
binding.pry
puts "jungle is massive"

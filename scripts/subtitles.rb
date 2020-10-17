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
      sanatised << line.gsub(/([^\w\s]|([0-9]|\:|\.))/, "").downcase
  end
  # remove dup lines with uniq then clean up formatting.
  aa = sanatised.uniq
  # reject any nil or empty strings
  aa.reject { |item| item.nil? || item == '  ' || item == ' ' || item == '\n' || item == ' \n' }
end

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

# test whether then db returns true or false on the user or kicks an error.
begin
  User.all.present?
rescue ActiveRecord::StatementInvalid => e
  puts "#{e}"
  puts "check the datbase has been created by running. rake subtitle:full_build"
  log_to_logfile.error("Program Closed: Database does not exist.")
  exit
end
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

# loop infinitely until the youtube address passes validation the exit
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
# create the hash for the subtitles
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

#------------------------------------------------------------------------------
# remove blasklist
#------------------------------------------------------------------------------
result = Hash.new {|h,k| h[k] = [] }

# flatten out the array of arrays
sublist = downloaded_subs['words'].flatten

# remove blacklist words from the array if they are found in the database.
subs = sublist.reject { |w| w if Blacklist.find_by(word: w) }

# group the words by themselves then count the words, sort and turn into a hash
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

  # subs_ints is remapped permanently altering the array. First it creates a
  # range of 50 words before and after i. Which is its index position. These
  # are then joined into the paragraph.
  subs_ints.map! {|i| pre = i - 50; pro = i + 50; pre = i if pre < 0; sublist[pre..pro].join(" ") }
  subs_ints.each {|paragraph| (result[:"#{k}"]||[]) << paragraph }
end

#------------------------------------------------------------------------------
# data sets and hashes for paragraphs
#------------------------------------------------------------------------------
# result paragraphs
paragraph = Hash.new { |h,k| h[k] = [] }

# remove from iterating over datasets
ignore_files = ["Blacklist", "User", "YoutubeResult"]

#------------------------------------------------------------------------------
# Load datasets
#------------------------------------------------------------------------------
# eager load the models keep it outside the loop so its only called once.
Rails.application.eager_load!

# For Rails5 models are now subclasses of ApplicationRecord so to get the list
# of all models in your app you do:
rails_models = ApplicationRecord.descendants.collect { |type| type.name }

# if datasets are not present exit and log otherwise print the count to screen.
if rails_models.present?
  logger.info("found #{rails_models.count} datasets")
else
  log_to_logfile.error("#{rails_models.count} datasets were found.")
  exit
end
#------------------------------------------------------------------------------
# Dataset words
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

    # rails_models are each dataset the words will be ran against.
    rails_models.each do |dataset|
      unless ignore_files.include?(dataset)

        #----------------------------------------------------------------------
        # words and sentence
        #----------------------------------------------------------------------
        # pluck all the words form the dataset. Filter out any words leaving
        # only sentences. Loop over each sentence, scanning the paragraph of
        # text (which is a string) for all occurrences of the sentence.
        ds = dataset.constantize.pluck(:word).keep_if {|x| x.split.count > 1 }
        ds.each {|x| rhash["#{dataset.underscore}"]["#{x}"] = para.scan(/#{x}/).count if para.scan(/#{x}/).count > 1 }

          # create a array of words from the database.
        if dataset.constantize.where(word: subs.keys).present?

          # where takes an array. In this case each key from the subs.keys
          # hash. And returns an array in one call of each found word.
          found_words = dataset.constantize.where(word: subs.keys)

          # loop over the found words. Creating the hash per paragraph.
          found_words.each { |word| rhash["#{dataset.underscore}"][word[:word]] = subs[word[:word]] }
        end
      end
    end
    #--------------------------------------------------------------------------
    # top words
    #--------------------------------------------------------------------------
    # hash count the words of the paragraphs
    top_ten_paragraph_words = para.split(" ").count_and_hash(10)
    #--------------------------------------------------------------------------
    # count all values
    #--------------------------------------------------------------------------
    # count the topics so as to rank the result based on the count.
    counted = Hash.new(0)
    count_result = Hash.new(0)

    rhash.keys.each {|k| rhash.dup[k].each {|key,val| counted[k] += val } }
    counted.each {|k,v| count_result[:rank] += v }
    #--------------------------------------------------------------------------
    # build paragraph
    #--------------------------------------------------------------------------
    # add the paragraph and dataset hash back into the array under its key
    (paragraph[k]||[]) << [para, top_ten_paragraph_words, rhash, count_result]
  end
end

#------------------------------------------------------------------------------
# rank the paragraphs - highest total
#------------------------------------------------------------------------------
new_par = Hash.new {|h,k| h[k] = [] }

# paragraphs_array
# 1) paragraph
# 2) top ten words count
# 3) hash of database words counted
paragraph.each do |k,arr|
  new_par[k] = arr.sort_by {|paragraph_array| paragraph_array[3][:rank] }
end

#------------------------------------------------------------------------------
# total the topics
#------------------------------------------------------------------------------
all_topics = Hash.new(0)

# paragraphs_array
    # 0) paragraph
    # 1) topten
    # 2) hash
paragraph.each do |top_key, arr|
  arr.each do |topic_array|
    topic_array[2].each { |k,v| all_topics[k] += v.values.sum }
  end
end

#------------------------------------------------------------------------------
# symbolize
#------------------------------------------------------------------------------
# symbolz are quicker, have a uniq id.
paragraph_symbolz = new_par.deep_symbolize_keys
paragraph_symbolz.each do |k,v|
  puts "#{k})\n"
  v.each_with_index do |par,i|
    puts "#{i}) #{par}"
    puts "\n"
  end
end

#------------------------------------------------------------------------------
# retrive json data
#------------------------------------------------------------------------------
# there are two files in the sub_path. *.json, *.vtt
# select the json returning an array.
file = sub_path.select {|f| f if File.extname(f.split("/")[-1]) =~ /.json/ }

if file.class == Array && file[0] =~ /.json/
  # open and parse json file
  data = JSON.parse(File.read(file[0]))
else
  log_to_logfile.error("RetriveJsonDataError: program closed due to #{file} error. no .json file.")
  logger.error("Error: no j.son data - check log for more thorough explanation")
  exit
end

#------------------------------------------------------------------------------
# format
#------------------------------------------------------------------------------
yt_user = User.find_or_create_by(uploader: data['uploader'], channel_id: data['channel_id'])
re = yt_user.youtube_results.find_or_create_by(title: data['title'])
re.update(duration: data['duration'], meta_data: {total: all_topics, top_count: top_count_hash})


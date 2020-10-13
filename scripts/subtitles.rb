#!/usr/bin/env ruby
require File.expand_path('../../config/environment', __FILE__)
require 'pry'
require 'json'
require 'logger'

# TODO: add frequency for some words.
# TODO: add sentences to the output, look at each paragraph or just result.
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
    self.group_by(&:itself).transform_values(&:count).sort_by{|k, v| v}.reverse.first(result).to_h
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

#------------------------------------------------------------------------------
# remove blasklist
#------------------------------------------------------------------------------
result = Hash.new {|h,k| h[k] = [] }

# flatten out the array of arrays
sublist = downloaded_subs['words'].flatten

# remove blacklist words from the array if they are found in the database.
subs = sublist.reject { |w| w if Blacklist.find_by(word: w) }

# group the words by themselfs then count the words, sort and turn into a hash
top_count_hash = subs.count_and_hash(10)

# top_count_hash iterates over the keys
# sublist iterates over each word of the subtitles. Each word it matches it stores
# the indices in the hash=result value array.
top_count_hash.keys.each do |k|
  sublist.each_with_index {|word,i| (result[k]||[]) << i if word =~ /#{k}/ }
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
# build paragraphs
#------------------------------------------------------------------------------
# build the paragrpahs
result.each do |k,v|
  logger.info("creating paragraphs for #{blue(k)}.")

  # value array that corrisponds to each key
  v.each do |word_position|

    # word_position is the words indicies. 50 is then subtracted or added.
    # Pre then denotes 50 words before the word Pro 50 after.
    pre = word_position - 50
    pro = word_position + 50

    # if pre is a minus set the variable to just the word_position
    if pre < 0
      pre = word_position
    end
    # -------------------------------------------------------------------------
    # Models
    # -------------------------------------------------------------------------
    # create hash for the results.
    rhash = Hash.new {|h,k| h[k] = Hash.new(0) }

    # rails_models = ApplicationRecord.descendants
    # k is used as the topic primary key
    # If the array_word is found its added to the rhash and count is incremented.
    rails_models.each do |k|
      unless ignore_files.include?(k)
        sublist[pre..pro].each {|array_word| rhash[k.underscore][array_word]+=1 if k.constantize.find_by(word: array_word) }
      end
    end
    # -------------------------------------------------------------------------
    # blacklist
    # -------------------------------------------------------------------------
    # remove words contained in the blacklist.
    par_array = sublist[pre..pro].reject { |w| w if Blacklist.find_by(word: w) }
    #--------------------------------------------------------------------------
    # top words
    #--------------------------------------------------------------------------
    # hash count the words of the paragrpahs
    top_ten_paragraph_words = par_array.count_and_hash(10)

    # count the syllables of each remaining word after the blacklist ahs been
    # removed and add the words over three syllables.
    high_syllables = par_array.delete_if {|word| syllable_count(word) < 3 }.count_and_hash(10)

    # remove the duplicates
    top_ten_paragraph_words.keys.each {|key| high_syllables.delete(key) }

    # merge the two hashes
    top_words = top_ten_paragraph_words.merge(high_syllables)

    #--------------------------------------------------------------------------
    # count all values
    #--------------------------------------------------------------------------
    counted = Hash.new(0)
    count_result = Hash.new(0)

    rhash.keys.each {|k| rhash.dup[k].each {|key,val| counted[k] += val } }
    counted.each {|k,v| count_result[:total] += v }

    #--------------------------------------------------------------------------
    # build paragraphs
    #--------------------------------------------------------------------------
    # use a range pre..pro to find the subtitles and join the words.
    # paragraphs <- array of paragraphs, counted words, topics, and a total of topics.
    (paragraph[k]||[]) << [sublist[pre..pro].join(" "), top_words, rhash, count_result]

  end

end

#------------------------------------------------------------------------------
# sentences
#------------------------------------------------------------------------------
# remove from iterating over datasets
ignore_files = ["Blacklist", "User", "YoutubeResult"]

# create hash for the results.
sentences = Hash.new { |h,k| h[k] = Hash.new(0) }

# the rails_models are eager_loaded at the start of the paragraph build.
# models refers to each model found in the ApplicationRecord.descendants
rails_models.each do |k|
  unless ignore_files.include?(k)

    # pluck words from each model.
    model_array = k.constantize.pluck(:word)
    sen = downloaded_subs['sentence'].flatten

    model_array.each do |word|
      if word.split.count > 1
        sen.each {|s| sentences[k][word] += 1 if s.include?(word) }
      end
    end

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
  (new_par[k]||[]) << arr.sort_by {|paragraph_array| paragraph_array[3][:total] }
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
# format
#------------------------------------------------------------------------------
new_par.each do |k,paragraph|
  puts "\n"
  puts "#{blue(k)} -> #{paragraph[0].count})\n"
  paragraph[0].each_with_index { |p,i| puts "\n" + "#{i}) #{p[0]} \n #{p[1]} \n #{p[2]} \n #{p[3]}" }
  div
end
puts "sentences"
puts sentences
div
all_topics.each {|k,v| puts "#{k} -> #{v} \n" }
div

#------------------------------------------------------------------------------
# retrive json data
#------------------------------------------------------------------------------
# there are two files in the sub_path. *.json, *.vtt
# select the json returning an array.
file = sub_path.select {|f| f if File.extname(f.split("/")[-1]) =~ /.json/ }

# open and parse json file
data = JSON.parse(File.read(file[0]))
#------------------------------------------------------------------------------
# format
#------------------------------------------------------------------------------
yt_user = User.find_or_create_by(uploader: data['uploader'], channel_id: data['channel_id'])
re = yt_user.youtube_results.find_or_create_by(title: data['title'])
re.update(duration: data['duration'], meta_data: {total: all_topics, top_count: top_count_hash})






#!/usr/bin/env ruby
require File.expand_path('../../config/environment', __FILE__)
require 'pry'
require 'json'
require 'logger'
require_relative 'helper'
require_relative 'logging'
require_relative 'y_t_process'
require_relative 'y_t_downloader'
require_relative 'y_t_history'

# include the youtube helper methods.
include YTHelper

# {{{1 command line args
# commend line args
$user_arg = ARGV
#}}}
#{{{1 close chrome

# close chrome.
kill_process("Chrome")

#}}}
# {{{1 logger
include Logging

# create a instance of logger for output to the sdtout
logger = logger_output(STDOUT)

# logger = STDOUT
logger.info("Program started...")

# }}}
# {{{1 test connection
#------------------------------------------------------------------------------

# The method Database_exists? Exits unless it is true that it exists.
log_to_logfile.error("Program Close: Database does not exist.") unless database_exists?
exit unless database_exists?

# Test whether the db has a User Model. If not it will exit the program.
has_db_been_populated

# }}}
# {{{1 remove old directories
#------------------------------------------------------------------------------

# Root directory.
root_dir = "/Users/shadowchaser/Downloads/Youtube_Subtitles/Subs"

# Remove the directory so its empty.
FileUtils.remove_dir(root_dir) if Dir.exist?(root_dir)
logger.info("removed #{root_dir}") if !Dir.exist?(root_dir)

# Remake the directory so its empty.
FileUtils.mkdir(root_dir) if !Dir.exist?(root_dir)
logger.info("re-created #{root_dir}") if Dir.exist?(root_dir)

# }}}
#{{{1 load datasets

# Eager loads the rails models. If datasets are not present exit and log,
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
include YTHistory

if Chrome.present?

  # Make a connection to the chrome db
  connect_to_chrome

  # Create a instance of Url.
  youtube = Url.new

  # Create a hash of the youtube results from the chrome history.
  youtube_urls_hash = youtube.youtube_urls_hash

  # Re-establish_connection to rails db.
  connect_to_rails

  # Populate chrome model.
  unless youtube_urls_hash.empty?
    youtube_urls_hash.each do |key, value|

      # Create or find the initial object based on title and url.
      youtube = Chrome.find_or_create_by(title: key, url: value[:url])
      if youtube.last_visit == nil
        youtube.update(visit_count: value[:visit_count] , last_visit: value[:last_visit])
      # Update the Chrome ActiveRecord if the last_visit has changed.
      elsif youtube.last_visit < value[:last_visit]
        youtube.update(visit_count: value[:visit_count] , last_visit: value[:last_visit])
      end

    end
  end
else
  raise "Chrome model does not exist"
  exit
end

# Exit if there are no chrome records.
unless Chrome.any?
  @logger.error("DownloadSubtitlesError: Please check Chrome Model exists")
  exit
end

#}}}
# {{{1 create subtitle paragraphs

# Environment variable.
home = ENV['HOME']

# Pass in the default youtube-dl downloads directory.
downloads = File.join(home, "Downloads/Youtube_Subtitles/Subs")

# Create an instance of subtitles downloader.
downloader = YTDownloader.new

# Download the subtitles providing an argument how many days ago.
# This creates a setter method `filepaths' making the filepaths available.
downloader.download_subtitles(1)

# create an instance of process.
process = YTProcess.new

# This creates a setter method subtitles.
process.create_subtitles(downloader.filepaths)

# Subtitles is a Hash with a title and a value array of subtitles.
process.create_paragraphs(process.subtitles)

# Build the dataset information for the paragraphs.
process.build_paragraph_datasets(process.paragraphs)

# Paragraph_dataset is the returned setter hash from build_paragraph_datasets.
process.sum_topic_values(process.paragraph_datasets)

# Pass in the Subtitle and title hash
process.sum_topten_titles(process.subtitles)

# Build the database entries. Paragraph_dataset is the returned setter hash from
# build_paragraph_datasets.
process.build_database(process.paragraph_datasets, process.filepaths)

# create a total of all the youtube_results adding them to the User model
# attribute `accumulator'.
process.total_users

#}}}

#!/usr/bin/env ruby

require 'pry'
require 'json'
require 'logger'

# TODO: log files to keep track.
#------------------------------------------------------------------------------
# logger
#------------------------------------------------------------------------------

def blue(color)
  "\e[34m#{color}\e[0m"
end

# log app status's
logger = Logger.new(STDOUT,
  level: Logger::INFO,
  progname: 'youtube',
  datetime_format: '%Y-%m-%d %H:%M:%S',
  formatter: proc do |severity, datetime, progname, msg|
    "[#{blue(progname)}][#{datetime}], #{severity}: #{msg}\n"
  end
)

logger.info("Youtube Subtitles Seeding...")

#------------------------------------------------------------------------------
# Files paths
#------------------------------------------------------------------------------

# Creates and array of absolute filepaths.
def sub_dir(directory_location)
    Dir.glob(directory_location + "/**/*").select{ |f| File.file? f }
end

home = ENV['HOME']
app_name = Rails.application.class.parent.to_s.underscore

# root data directory.
root = "#{home}/Code/Ruby/Projects/#{app_name}/lib/data"

# filepaths to each file.
filepaths = sub_dir(root)
logger.info("#{filepaths.count} files found in the filepath") if filepaths.present?


#------------------------------------------------------------------------------
# Create data sets
#------------------------------------------------------------------------------

# openfiles and create arrays
filepaths.each do |data_file|

  # read each file
  file = File.read(data_file)
  data_hash = JSON.parse(file)

  # each files key and v == array
  data_hash.each do |k,v|

    # check the model table exists in the db and has no entries.
    unless k.constantize.count > 0
    logger.info("currently seeding #{k}")

      # loop through each word in the json array.
      v.each do |item|
        k.constantize.find_or_create_by(word: item)
      end
    end

  end

end


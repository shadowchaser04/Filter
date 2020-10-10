#!/usr/bin/env ruby

require 'pry'
require 'json'
require 'logger'

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
      # loop through each word in the blist array.
      v.each do |item|
        k.constantize.find_or_create_by(word: item)
      end
    end

  end

end


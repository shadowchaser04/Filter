#!/usr/bin/env ruby

require 'pry'
require 'json'
require 'logger'

#------------------------------------------------------------------------------
# Data
#------------------------------------------------------------------------------
# predicates_audio 
# predicates_gustatory
# predicates_kinesthetic 
# predicates_olfactory 
# predicates_visual  
# sentiment_negative 
# sentiment_posative  
# family  
# political_campaigne 
# political_systems 
# political_vocabulary
# religion 
# spirituality

#------------------------------------------------------------------------------
# Files paths
#------------------------------------------------------------------------------

# Creates and array of absolute filepaths.
def sub_dir(directory_location)
    Dir.glob(directory_location + "/**/*").select{ |f| File.file? f }
end

# root data directory.
root = "/Users/shadowchaser/Code/Ruby/Projects/youtube_filter/lib/data"

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

    # check if table exists and the model is empty.
    unless k.constantize.count > 0
      # loop through each word in the blist array.
      v.each do |item|
        k.constantize.find_or_create_by(word: item)
      end
    end

  end

end


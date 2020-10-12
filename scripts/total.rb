#!/usr/bin/env ruby
require File.expand_path('../../config/environment', __FILE__)
require 'pry'
require 'json'
require 'logger'

# TODO: add top_ten count of words.

result_hash = Hash.new {|h,k| h[k] = Hash.new(0) }

# iterate over each User tallying the results of all the youtube_results.
User.all.each do |item|

  # reset the accumulated_duration so it can be rebuilt dedendent on any
  # changes to its size.
  item[:accumulated_duration] = 0

  # iterate over each assosiaction record belonging to the user.
  item.youtube_results.each do |obj|

    # retrive the json hash - :meta_data and iterate over each k,v pair adding
    # the key and counting the value to the result hash.
    obj[:meta_data]['total'].each {|k,v| result_hash["#{item[:uploader]}"][k] += v }

    # accumulate each of the durations.
    item[:accumulated_duration] += obj[:duration]
  end

  # add the count to the video_count attribute and update the last updated
  # accumulated_duration attribute.
  item.update(video_count: item.youtube_results.count, accumulator_last_update: Time.now)
end

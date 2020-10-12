#!/usr/bin/env ruby
require File.expand_path('../../config/environment', __FILE__)
require 'pry'
require 'json'
require 'logger'

# TODO: add top_ten count of words.

result_hash = Hash.new {|h,k| h[k] = Hash.new(0) }

# iterate over each User tallying the results of all the youtube_results.
User.all.each do |item|

  # iterate over each assosiaction record belonging to the user.
  item.youtube_results.each do |obj|

    # retrive the json hash - :meta_data and iterate over each k,v pair adding
    # the key and counting the value to the result hash.
    obj[:meta_data]['total'].each {|k,v| result_hash["#{item[:uploader]}"][k] += v }

    # accumulate each of the durations.
    result_hash["#{item[:uploader]}"][:duration] += obj[:duration]
  end

end

# time for stupid reasons
t = Time.now

# build
result_hash.each do |k,v|

  # find each occurence of the user.
  u = User.find_by(uploader: k)

  # update the attributes.
  u.update(accumulator: v, accumulated_duration:v[:duration],  accumulator_last_update: t)

  # remove the duration
  u[:accumulator].delete("duration")

  # re add the hash via update.
  u.update(accumulator: u[:accumulator])

end



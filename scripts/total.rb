#!/usr/bin/env ruby
require File.expand_path('../../config/environment', __FILE__)
require 'pry'
require 'json'
require 'logger'

# TODO: add total duration time. this can be used to look at frequency later.
result_hash = Hash.new {|h,k| h[k] = Hash.new(0) }

# iterate over each User
User.all.each do |item|

  # iterate over each assosiaction record belonging to the user.
  item.youtube_results.each do |obj|

    # retrive the json hash - :meta_data and iterate over each k,v pair adding
    # the key and counting the value to the result hash.
    obj[:meta_data]['total'].each {|k,v| result_hash["#{item[:uploader]}"][k] += v }

  end

end

# time for stupid reasons
t = Time.now

# build
result_hash.each {|k,v| User.find_by(uploader: k).update(accumulator: v, accumulator_last_update: t) }


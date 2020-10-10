#!/usr/bin/env ruby
require File.expand_path('../../config/environment', __FILE__)
require 'pry'
require 'json'
require 'logger'

result_hash = Hash.new {|h,k| h[k] = Hash.new(0) }

User.all.each do |item|
  item.youtube_results.each do |obj|
    obj[:meta_data]['total'].each {|k,v| result_hash["#{item[:uploader]}"][k] += v }
  end
end

# time for stupid reasons
t = Time.now

# build
result_hash.each {|k,v| User.find_by(uploader: k).update(accumulator: v, accumulator_last_update: t) }


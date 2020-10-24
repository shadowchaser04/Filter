#!/usr/bin/env ruby
require File.expand_path('../../config/environment', __FILE__)
require 'pry'
require 'json'
require 'logger'


arr = ["one", "two", "three", "four", "five", "one", "two"]

arr.each_with_object(Hash.new(0)) do |item, count_hash|
  if count_hash[item]
    count_hash[item] += 1
  else
    count_hash[item] = 1
  end
  binding.pry
end

binding.pry
puts arr






















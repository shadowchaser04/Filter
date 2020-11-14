#!/usr/bin/env ruby
require File.expand_path('../../config/environment', __FILE__)
require 'pry'
require 'json'
require 'logger'

binding.pry
ar = (1..10000000).to_a

t = Time.now
ar.select {|a| a.even? }
puts "select: #{Time.now - t}"

t = Time.now
ar.select(&:even?)
puts "select: #{Time.now - t}"

t = Time.now
ar.select! {|a| a.even? }
puts "select: #{Time.now - t}"

t = Time.now
ar.reject {|a| a.even? }
puts "reject: #{Time.now - t}"


binding.pry
puts "bench"

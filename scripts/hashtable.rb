#!/usr/bin/env ruby
require File.expand_path('../../config/environment', __FILE__)
require 'pry'
require 'json'
require 'logger'

class HashTable

  def initialize
    @table = Array.new(9122, nil)
  end

  def calculate_hash_value(string)
    value = string[0].ord * 100 + string[1].ord
    value
  end

  def store(string)
      hash_value = calculate_hash_value(string)

      if @table[hash_value] != nil
        @table[hash_value].append(string)
      else
        @table[hash_value] = [string]
      end
  end

  def lookup(string)
      hash_value = calculate_hash_value(string)

      if @table[hash_value] != nil
        if @table[hash_value].include?(string)
          return hash_value
        end
      end

      "String not found"

  end

  def compact
    @table.compact
  end

end

# puts stuff
person_list = HashTable.new

person_list.store("damien")

binding.pry
person_list.compact


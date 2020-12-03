#!/usr/bin/env ruby
require File.expand_path('../../config/environment', __FILE__)
require 'pry'

class Encryption

  attr_accessor :hashy

  def initialize(shift)
    @shift = shift
    @hashy = Hash.new
  end

  def encrypt(string)
    string_to_ascii_array = string.chars.map {|char| char.ord}
    shifted = string_to_ascii_array.map {|char| char+@shift}
    word = shifted.map! { |char| char.chr }.join
    hex = hex_me
    @hashy[hex] = word
    return hex
  end

  def decrypt(string)
    string_to_ascii_array = string.chars.map {|char| char.ord}
    shifted = string_to_ascii_array.map {|char| char-@shift}
    shifted.map { |char| char.chr }.join
  end

  def hex_me
    SecureRandom.hex
  end

  def unencrypt(hex_key)
    decrypt(@hashy[hex_key])
  end

end

# create an instance of encryption and set the shift
# the shift moves the ordinal position + and - @shift
cypher = Encryption.new(10)

# create a key and encrypt
mykey = cypher.encrypt("password")

binding.pry
# un-encrypt
cypher.unencrypt(mykey)


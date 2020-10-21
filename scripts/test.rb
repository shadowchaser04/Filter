#!/usr/bin/env ruby
require File.expand_path('../../config/environment', __FILE__)
require 'pry'
require 'json'
require 'logger'

class Hash
  def fetch_in(*keys, **kwargs, &block)
    keys = keys.dup
    ckey = keys.shift

    unless self.key?(ckey)
      return kwargs[:default] if kwargs.key?(:default)
      return block.call(ckey) if block
      fail KeyError, "key not found #{ckey.inspect}"
    end

    child = self[ckey]

    if keys.empty?
      child
    elsif child.respond_to?(:fetch_in)
      child.fetch_in(*keys, **kwargs, &block)
    else
      fail ArgumentError, 'more keys than Hashes'
    end
  end
end

a = {
  a: {
    b: {
      c: :d
    }
  }
}

def y
  yield
rescue => e
  e
end

binding.pry
puts ""

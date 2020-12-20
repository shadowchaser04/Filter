#!/usr/bin/env ruby
require File.expand_path('../../config/environment', __FILE__)
require 'pry'
require 'json'

class Node

  attr_reader :value
  attr_accessor :left, :right

  def initialize(value)
    @value = value
    @left =nil
    @right =nil
  end

end

 ## smaller value goes left, bigger value goes right, equal goes right
  def pushNode(node, value)
    if(value > node.value)
      if(node.right)
        pushNode(node.right, value)
      else
        node.right = Node.new(value)
      end
      else
      if(node.left)
        pushNode(node.left, value)
      else
        node.left = Node.new(value)
      end
    end
    binding.pry
  end

arr = [5,6,2,4,1,8,7,9,3]

root = Node.new(arr.shift)

binding.pry
arr.each{|e| pushNode(root, e) }
binding.pry
puts "finish"

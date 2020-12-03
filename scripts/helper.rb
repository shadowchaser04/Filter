#!/usr/bin/env ruby
require File.expand_path('../../config/environment', __FILE__)
require 'pry'
require 'json'
require 'logger'
require_relative 'y_t_history'
require_relative 'y_t_downloader'
require_relative 'y_t_process'
require_relative 'logging'

# {{{1 helper
module YTHelper

  #{{{2 array
  # Counts each occurence of the word by the group_by method and hashes the result.
  class Array
    def count_and_hash
      self.group_by(&:itself).transform_values(&:count).sort_by{|k, v| v}.reverse.to_h
    end
  end

  #}}}
  # {{{2 string
  # snake case a constant
  class String
    def underscore
      self.gsub(/::/, '/').
      gsub(/([A-Z]+)([A-Z][a-z])/,'\1_\2').
      gsub(/([a-z\d])([A-Z])/,'\1_\2').
      tr("-", "_").
      downcase
    end
  end

  #}}}
  # {{{2 private
  private def nested_hash
      Hash.new {|h,k| h[k] = Hash.new }
  end

  private def nested_hash_default
    Hash.new { |h,k| h[k] = Hash.new(0) }
  end

  private def hash_nested_array
    Hash.new { |h,k| h[k] = [] }
  end
  #}}}
  # {{{2 format
  #------------------------------------------------------------------------------
  def blue(color)
    "\e[34m#{color}\e[0m"
  end
  # }}}
  # {{{2 kill process
  def kill_process(word)
    `ps aux | grep #{word} | awk '{print $2}' | xargs kill -9`
  end
  #}}}
  # {{{2 db
  def database_exists?
    ActiveRecord::Base.connection
  rescue ActiveRecord::NoDatabaseError
    false
  else
    true
  end

  # NOTE: problem with any attempt to deal with this.
  # test whether then db returns true or false on the user or kicks an error.
  def has_db_been_populated
    User.all.exists?
  end

  # eager load the models keep it outside the loop so its only called once.
  # For Rails5 models are now subclasses of ApplicationRecord so to get the list
  # of all models in your app you do:
  def load_models
    Rails.application.eager_load!
    return ApplicationRecord.descendants.collect { |type| type.name }
  end
  #}}}

end

#}}}

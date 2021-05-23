#!/usr/bin/env ruby
require File.expand_path('../../config/environment', __FILE__)
require 'pry'
require 'json'
require 'logger'

# logger {{{1
#------------------------------------------------------------------------------
# log app status's

module Logging

  def logger_output(choice_of_output)
      Logger.new(choice_of_output,
      level: Logger::INFO,
      progname: 'youtube',
      datetime_format: '%Y-%m-%d %H:%M:%S',
      formatter: proc do |severity, datetime, progname, msg|
        "[#{blue(progname)}][#{datetime}], #{severity}: #{msg}\n"
      end
    )
  end

end


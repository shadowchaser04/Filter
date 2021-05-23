#!/usr/bin/env ruby
require File.expand_path('../../config/environment', __FILE__)

# youtube helper {{{1
module YTHelper

  # eager load the models keep it outside the loop so its only called once.
  # For Rails5 models are now subclasses of ApplicationRecord so to get the list
  # of all models in your app you do:
  def load_models
    Rails.application.eager_load!
    return ApplicationRecord.descendants.collect { |type| type.name }
  end

  # establish the db exists
  def database_exists?
    ActiveRecord::Base.connection
  rescue ActiveRecord::NoDatabaseError
    false
  else
    true
  end

end
# }}}

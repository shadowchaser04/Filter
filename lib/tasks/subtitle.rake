#!/usr/bin/env ruby
require "pry"

# Creates and array of absolute filepaths.
def sub_dir(directory_location)
    Dir.glob(directory_location + "/**/*").select{ |f| File.file? f }
end

# root data directory.
root = Rails.root.join('lib/data').to_s

# filepaths to each file.
namespace :subtitle do

  desc "build all models corrisponding to the datasets Example: subtitle:build_models"
  task :build_models => :environment do

    # datasets paths
    filepaths = sub_dir(root)

    # iterate over each file of the datasets
    filepaths.each do |file|

      # remove the file extension leaving just the end of the file name.
      name = File.basename(file,File.extname(file))

      # eager load the models
      Rails.application.eager_load!

      # For Rails5 models are now subclasses of ApplicationRecord so to get list of all models in your app you do:
      rails_models = ApplicationRecord.descendants.collect { |type| type.name }

      unless rails_models.include?(name.camelize)
        sh "rails g model #{name.camelize} word:string --no-timestamps"
      end
    end
  end

  desc "create the user model"
  task user: :environment do
    sh "rails g model User uploader:string channel_id:string video_count:integer accumulated_duration:integer accumulator:json accumulator_last_update:datetime --no-timestamps"
  end

  desc "create the result model"
  task result: :environment do
    sh "rails g model YoutubeResult title:string duration:integer meta_data:json user:references --no-timestamps"
  end

  desc "build full filter app"
  task full_build: :environment do

    # build subtitles user model NOTE: this does not add the has_many assosh.
    sh "rake subtitle:user"

    # build the belongs_to association between User and YoutubeResult.
    sh "rake subtitle:result"

    # build the models for each of the datasets found in the filepath.
    sh "rake subtitle:build_models"

    sh "rake db:migrate"
    sh "rake db:seed"
  end

end

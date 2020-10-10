# Creates and array of absolute filepaths.
def sub_dir(directory_location)
    Dir.glob(directory_location + "/**/*").select{ |f| File.file? f }
end

# root data directory.
root = "/Users/shadowchaser/Code/Ruby/Projects/youtube_filter/lib/data"

# filepaths to each file.
filepaths = sub_dir(root)

namespace :subtitle do

  desc "build all models corrisponding to the datasets Example: subtitle:build_models"
  task :build_models => :environment do

    # iterate over each file of the datasets
    filepaths.each do |name|

      # eager load the models
      Rails.application.eager_load!

      # For Rails5 models are now subclasses of ApplicationRecord so to get list of all models in your app you do:
      rails_models = ApplicationRecord.descendants.collect { |type| type.name }

      unless rails_models.include?(name)
        sh "rails g model #{name.camelize} word:string --no-timestamps"
      end
    end
  end

  desc "create the user model"
  task user: :environment do
    sh "rails g model User uploader:string channel_id:integer --no-timestamps"
  end

  desc "create the result model"
  task result: :environment do
    sh "rails g model YoutubeResult title:string duration:integer meta_data:json user:references --no-timestamps"
  end

  desc "build full filter app"
  task full_build: :environment do
    rake "subtitle:user"
    rake "subtitle:result"
    rake "subtitle:build_models"
    rake "db:migrate"
    rake "db:seed"
  end

end

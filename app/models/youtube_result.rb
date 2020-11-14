class YoutubeResult < ApplicationRecord
  belongs_to :user
  has_many :subtitles
end

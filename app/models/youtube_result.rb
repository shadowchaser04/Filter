class YoutubeResult < ApplicationRecord
  belongs_to :user
  has_one :subtitle
end

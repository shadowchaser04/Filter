class User < ApplicationRecord
  has_many :youtube_results, dependent: :destroy
end

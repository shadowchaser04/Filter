class User < ApplicationRecord
  #-----------------------------------------------------------------------------
  # assosiations
  #-----------------------------------------------------------------------------
  has_many :youtube_results, dependent: :destroy

end

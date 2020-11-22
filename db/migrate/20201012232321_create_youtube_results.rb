class CreateYoutubeResults < ActiveRecord::Migration[6.0]
  def change
    create_table :youtube_results do |t|
      t.string :title
      t.integer :duration
      t.json :total
      t.json :topten
      t.references :user, null: false, foreign_key: true
    end
  end
end

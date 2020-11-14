class CreateSubtitles < ActiveRecord::Migration[6.0]
  def change
    create_table :subtitles do |t|
      t.string :title
      t.json :paragraph
      t.references :youtube_result, null: false, foreign_key: true
    end
  end
end

class CreateTvshows < ActiveRecord::Migration[6.0]
  def change
    create_table :tvshows do |t|
      t.string :word
    end
  end
end

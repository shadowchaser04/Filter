class CreateMovieIndustries < ActiveRecord::Migration[6.0]
  def change
    create_table :movie_industries do |t|
      t.string :word
    end
  end
end

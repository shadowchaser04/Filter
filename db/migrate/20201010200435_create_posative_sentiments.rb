class CreatePosativeSentiments < ActiveRecord::Migration[6.0]
  def change
    create_table :posative_sentiments do |t|
      t.string :word
    end
  end
end

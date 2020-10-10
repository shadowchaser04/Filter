class CreateNegativeSentiments < ActiveRecord::Migration[6.0]
  def change
    create_table :negative_sentiments do |t|
      t.string :word
    end
  end
end

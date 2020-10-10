class CreateProfanityProfanes < ActiveRecord::Migration[6.0]
  def change
    create_table :profanity_profanes do |t|
      t.string :word
    end
  end
end

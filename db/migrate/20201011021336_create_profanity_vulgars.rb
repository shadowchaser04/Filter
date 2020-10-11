class CreateProfanityVulgars < ActiveRecord::Migration[6.0]
  def change
    create_table :profanity_vulgars do |t|
      t.string :word
    end
  end
end

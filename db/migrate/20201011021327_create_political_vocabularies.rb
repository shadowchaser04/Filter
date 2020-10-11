class CreatePoliticalVocabularies < ActiveRecord::Migration[6.0]
  def change
    create_table :political_vocabularies do |t|
      t.string :word
    end
  end
end

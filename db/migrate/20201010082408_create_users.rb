class CreateUsers < ActiveRecord::Migration[6.0]
  def change
    create_table :users do |t|
      t.string :uploader
      t.string :channel_id
      t.json :accumulator
    end
  end
end

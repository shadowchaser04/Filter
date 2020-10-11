class CreateUsers < ActiveRecord::Migration[6.0]
  def change
    create_table :users do |t|
      t.string :uploader
      t.string :channel_id
      t.integer :accumulated_duration
      t.json :accumulator
      t.datetime :accumulator_last_update
    end
  end
end

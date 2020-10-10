class CreateUsers < ActiveRecord::Migration[6.0]
  def change
    create_table :users do |t|
      t.string :uploader
      t.integer :channel_id
    end
  end
end

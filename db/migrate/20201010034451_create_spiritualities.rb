class CreateSpiritualities < ActiveRecord::Migration[6.0]
  def change
    create_table :spiritualities do |t|
      t.string :word
    end
  end
end

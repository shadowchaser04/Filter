class CreateActresses < ActiveRecord::Migration[6.0]
  def change
    create_table :actresses do |t|
      t.string :word
    end
  end
end

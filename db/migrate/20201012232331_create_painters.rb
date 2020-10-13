class CreatePainters < ActiveRecord::Migration[6.0]
  def change
    create_table :painters do |t|
      t.string :word
    end
  end
end

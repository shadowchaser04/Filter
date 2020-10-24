class CreateLiteratures < ActiveRecord::Migration[6.0]
  def change
    create_table :literatures do |t|
      t.string :word
    end
  end
end

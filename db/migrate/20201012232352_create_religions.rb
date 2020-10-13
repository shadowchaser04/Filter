class CreateReligions < ActiveRecord::Migration[6.0]
  def change
    create_table :religions do |t|
      t.string :word
    end
  end
end

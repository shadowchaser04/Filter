class CreateUfcs < ActiveRecord::Migration[6.0]
  def change
    create_table :ufcs do |t|
      t.string :word
    end
  end
end

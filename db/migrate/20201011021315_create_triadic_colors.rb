class CreateTriadicColors < ActiveRecord::Migration[6.0]
  def change
    create_table :triadic_colors do |t|
      t.string :word
    end
  end
end

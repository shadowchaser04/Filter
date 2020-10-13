class CreateTertiaryColors < ActiveRecord::Migration[6.0]
  def change
    create_table :tertiary_colors do |t|
      t.string :word
    end
  end
end

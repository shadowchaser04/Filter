class CreateAnalogousColors < ActiveRecord::Migration[6.0]
  def change
    create_table :analogous_colors do |t|
      t.string :word
    end
  end
end

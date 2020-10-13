class CreateComplimentaryColors < ActiveRecord::Migration[6.0]
  def change
    create_table :complimentary_colors do |t|
      t.string :word
    end
  end
end

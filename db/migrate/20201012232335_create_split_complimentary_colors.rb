class CreateSplitComplimentaryColors < ActiveRecord::Migration[6.0]
  def change
    create_table :split_complimentary_colors do |t|
      t.string :word
    end
  end
end

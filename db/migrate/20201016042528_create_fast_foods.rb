class CreateFastFoods < ActiveRecord::Migration[6.0]
  def change
    create_table :fast_foods do |t|
      t.string :word
    end
  end
end

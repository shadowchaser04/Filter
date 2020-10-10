class CreatePoets < ActiveRecord::Migration[6.0]
  def change
    create_table :poets do |t|
      t.string :word
    end
  end
end

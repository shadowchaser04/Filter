class CreateMmas < ActiveRecord::Migration[6.0]
  def change
    create_table :mmas do |t|
      t.string :word
    end
  end
end

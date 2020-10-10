class CreateOlfactories < ActiveRecord::Migration[6.0]
  def change
    create_table :olfactories do |t|
      t.string :word
    end
  end
end

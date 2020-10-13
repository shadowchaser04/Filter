class CreatePhilosophies < ActiveRecord::Migration[6.0]
  def change
    create_table :philosophies do |t|
      t.string :word
    end
  end
end

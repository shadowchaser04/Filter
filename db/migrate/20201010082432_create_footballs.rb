class CreateFootballs < ActiveRecord::Migration[6.0]
  def change
    create_table :footballs do |t|
      t.string :word
    end
  end
end

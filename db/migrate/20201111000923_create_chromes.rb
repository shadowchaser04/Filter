class CreateChromes < ActiveRecord::Migration[6.0]
  def change
    create_table :chromes do |t|
      t.string :title
      t.string :url
      t.integer :visit_count
      t.datetime :last_visit
    end
  end
end

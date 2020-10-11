class CreateGustatories < ActiveRecord::Migration[6.0]
  def change
    create_table :gustatories do |t|
      t.string :word
    end
  end
end

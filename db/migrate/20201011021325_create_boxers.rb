class CreateBoxers < ActiveRecord::Migration[6.0]
  def change
    create_table :boxers do |t|
      t.string :word
    end
  end
end

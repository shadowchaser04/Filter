class CreateKinesthetics < ActiveRecord::Migration[6.0]
  def change
    create_table :kinesthetics do |t|
      t.string :word
    end
  end
end

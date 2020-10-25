class CreateIllnesses < ActiveRecord::Migration[6.0]
  def change
    create_table :illnesses do |t|
      t.string :word
    end
  end
end

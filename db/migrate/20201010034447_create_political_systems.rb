class CreatePoliticalSystems < ActiveRecord::Migration[6.0]
  def change
    create_table :political_systems do |t|
      t.string :word
    end
  end
end

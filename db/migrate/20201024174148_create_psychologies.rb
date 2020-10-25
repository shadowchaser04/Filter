class CreatePsychologies < ActiveRecord::Migration[6.0]
  def change
    create_table :psychologies do |t|
      t.string :word
    end
  end
end

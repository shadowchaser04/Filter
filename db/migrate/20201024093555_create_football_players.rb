class CreateFootballPlayers < ActiveRecord::Migration[6.0]
  def change
    create_table :football_players do |t|
      t.string :word
    end
  end
end

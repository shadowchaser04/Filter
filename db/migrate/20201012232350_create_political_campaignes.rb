class CreatePoliticalCampaignes < ActiveRecord::Migration[6.0]
  def change
    create_table :political_campaignes do |t|
      t.string :word
    end
  end
end

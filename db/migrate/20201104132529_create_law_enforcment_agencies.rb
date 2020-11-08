class CreateLawEnforcmentAgencies < ActiveRecord::Migration[6.0]
  def change
    create_table :law_enforcment_agencies do |t|
      t.string :word
    end
  end
end

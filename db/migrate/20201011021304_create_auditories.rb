class CreateAuditories < ActiveRecord::Migration[6.0]
  def change
    create_table :auditories do |t|
      t.string :word
    end
  end
end

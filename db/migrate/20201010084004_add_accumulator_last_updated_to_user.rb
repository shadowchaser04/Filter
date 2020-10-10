class AddAccumulatorLastUpdatedToUser < ActiveRecord::Migration[6.0]
  def change
    add_column :users, :accumulator_last_update, :datetime
  end
end

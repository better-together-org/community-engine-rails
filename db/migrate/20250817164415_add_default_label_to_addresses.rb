class AddDefaultLabelToAddresses < ActiveRecord::Migration[7.1]
  def change
    change_column_default :better_together_addresses, :label, 'main'
  end
end

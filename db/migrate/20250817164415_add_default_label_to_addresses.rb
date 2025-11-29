# frozen_string_literal: true

class AddDefaultLabelToAddresses < ActiveRecord::Migration[7.1] # rubocop:todo Style/Documentation
  def change
    change_column_default :better_together_addresses, :label, 'main'
  end
end

# frozen_string_literal: true

# Allows addresses to not be linked to a contact detail.
class RemoveColumnNullOnBetterTogetherAddressesContactDetailId < ActiveRecord::Migration[7.1]
  def change
    change_column_null :better_together_addresses, :contact_detail_id, true
  end
end

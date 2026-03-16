# frozen_string_literal: true

class AddMembershipRequestFieldsToJoatuRequests < ActiveRecord::Migration[7.1] # :nodoc:
  def change
    add_column :better_together_joatu_requests, :requestor_name, :string
    add_column :better_together_joatu_requests, :requestor_email, :string
    add_column :better_together_joatu_requests, :referral_source, :string

    add_index :better_together_joatu_requests, :requestor_email,
              name: 'index_bt_joatu_requests_on_requestor_email'
  end
end

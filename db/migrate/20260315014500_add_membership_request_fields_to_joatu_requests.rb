# frozen_string_literal: true

# Adds requestor_name, requestor_email, and referral_source to Joatu requests
# to support unauthenticated membership request submissions.
class AddMembershipRequestFieldsToJoatuRequests < ActiveRecord::Migration[7.2]
  def change
    add_column :better_together_joatu_requests, :requestor_name, :string
    add_column :better_together_joatu_requests, :requestor_email, :string
    add_column :better_together_joatu_requests, :referral_source, :string

    add_index :better_together_joatu_requests, :requestor_email,
              name: 'index_bt_joatu_requests_on_requestor_email'
  end
end

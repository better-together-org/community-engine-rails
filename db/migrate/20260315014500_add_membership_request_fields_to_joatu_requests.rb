# frozen_string_literal: true

class AddMembershipRequestFieldsToJoatuRequests < ActiveRecord::Migration[7.1] # :nodoc:
  TABLE = :better_together_joatu_requests
  private_constant :TABLE
  def up
    add_columns
    add_indexes
  end

  def down
    type_idx = 'index_better_together_joatu_requests_on_type'
    email_idx = 'index_bt_joatu_requests_on_requestor_email'
    remove_index TABLE, name: email_idx if index_exists?(TABLE, :requestor_email, name: email_idx)
    remove_index TABLE, name: type_idx if index_exists?(TABLE, :type, name: type_idx)
    remove_column TABLE, :referral_source if column_exists?(TABLE, :referral_source)
    remove_column TABLE, :requestor_email if column_exists?(TABLE, :requestor_email)
    remove_column TABLE, :requestor_name if column_exists?(TABLE, :requestor_name)
    remove_column TABLE, :type if column_exists?(TABLE, :type)
  end

  private

  def add_columns
    add_column TABLE, :type, :string, default: 'BetterTogether::Joatu::Request', null: false unless column_exists?(TABLE, :type)
    add_column TABLE, :requestor_name, :string unless column_exists?(TABLE, :requestor_name)
    add_column TABLE, :requestor_email, :string unless column_exists?(TABLE, :requestor_email)
    add_column TABLE, :referral_source, :string unless column_exists?(TABLE, :referral_source)
  end

  def add_indexes
    unless index_exists?(TABLE, :type, name: 'index_better_together_joatu_requests_on_type')
      add_index TABLE, :type, name: 'index_better_together_joatu_requests_on_type'
    end
    return if index_exists?(TABLE, :requestor_email, name: 'index_bt_joatu_requests_on_requestor_email')

    add_index TABLE, :requestor_email, name: 'index_bt_joatu_requests_on_requestor_email'
  end
end

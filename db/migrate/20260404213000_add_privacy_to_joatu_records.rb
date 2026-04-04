class AddPrivacyToJoatuRecords < ActiveRecord::Migration[7.1]
  def change
    add_privacy_column(:better_together_joatu_requests)
    add_privacy_column(:better_together_joatu_offers)
    add_privacy_column(:better_together_joatu_agreements)
  end

  private

  def add_privacy_column(table_name)
    return if column_exists?(table_name, :privacy)

    add_column table_name, :privacy, :string, null: false, default: 'private'
    add_index table_name, :privacy unless index_exists?(table_name, :privacy)
  end
end

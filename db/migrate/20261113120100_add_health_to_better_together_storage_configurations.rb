# frozen_string_literal: true

# Records the outcome of the last connection test on a storage configuration, so an admin can see
# whether a platform's bucket is reachable without running a test by hand.
class AddHealthToBetterTogetherStorageConfigurations < ActiveRecord::Migration[7.2]
  TABLE = :better_together_storage_configurations

  def change
    return unless table_exists?(TABLE)

    add_column TABLE, :health_status, :string unless column_exists?(TABLE, :health_status)
    add_column TABLE, :health_message, :string unless column_exists?(TABLE, :health_message)
    add_column TABLE, :health_checked_at, :datetime unless column_exists?(TABLE, :health_checked_at)
  end
end

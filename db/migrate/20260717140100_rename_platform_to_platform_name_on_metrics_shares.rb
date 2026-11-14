# frozen_string_literal: true

# Renames Metrics::Share's `platform` string column (the share network name,
# e.g. "facebook") to `platform_name`, matching the naming convention already
# used by SocialMediaAccount (`platform_name` for the network, `platform`/
# `platform_id` via PlatformScoped for the real tenant). This resolves a
# naming collision that previously prevented Share from including
# BetterTogether::Metrics::PlatformScoped like its sibling metrics models —
# `platform` was already taken by the network-name column.
class RenamePlatformToPlatformNameOnMetricsShares < ActiveRecord::Migration[7.2]
  OLD_INDEX = 'index_better_together_metrics_shares_on_platform_and_url'
  NEW_INDEX = 'index_better_together_metrics_shares_on_platform_name_and_url'

  def up
    return unless column_exists?(:better_together_metrics_shares, :platform)

    remove_index :better_together_metrics_shares, name: OLD_INDEX if index_name_exists?(:better_together_metrics_shares, OLD_INDEX)
    rename_column :better_together_metrics_shares, :platform, :platform_name

    return if index_name_exists?(:better_together_metrics_shares, NEW_INDEX)

    add_index :better_together_metrics_shares, %i[platform_name url], name: NEW_INDEX
  end

  def down
    return unless column_exists?(:better_together_metrics_shares, :platform_name)

    remove_index :better_together_metrics_shares, name: NEW_INDEX if index_name_exists?(:better_together_metrics_shares, NEW_INDEX)
    rename_column :better_together_metrics_shares, :platform_name, :platform

    return if index_name_exists?(:better_together_metrics_shares, OLD_INDEX)

    add_index :better_together_metrics_shares, %i[platform url], name: OLD_INDEX
  end
end

# frozen_string_literal: true

# A provider identity (provider + uid) is now linked per local platform: the same GitHub or Google
# account may be linked to different people on different platforms. Existing links belong to the host platform.
class AddLocalPlatformToBetterTogetherPersonPlatformIntegrations < ActiveRecord::Migration[7.2]
  TABLE = :better_together_person_platform_integrations
  INDEX = 'idx_bt_ppi_provider_uid_local_platform'

  def up
    unless column_exists?(TABLE, :local_platform_id)
      add_reference TABLE, :local_platform, type: :uuid, null: true, index: true,
                                            foreign_key: { to_table: :better_together_platforms }
    end

    backfill_host_platform
    return if index_name_exists?(TABLE, INDEX)

    add_index TABLE, %i[provider uid local_platform_id], unique: true, name: INDEX
  end

  def down
    remove_index TABLE, name: INDEX if index_name_exists?(TABLE, INDEX)
    remove_reference TABLE, :local_platform, foreign_key: { to_table: :better_together_platforms } if column_exists?(TABLE, :local_platform_id)
  end

  private

  def backfill_host_platform
    host_id = select_value('SELECT id FROM better_together_platforms WHERE host = TRUE ORDER BY created_at LIMIT 1')
    return unless host_id

    execute("UPDATE #{TABLE} SET local_platform_id = #{quote(host_id)} WHERE local_platform_id IS NULL")
  end
end

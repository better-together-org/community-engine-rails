# frozen_string_literal: true

# Geography::Map had no platform association at all, unlike every other
# platform-scoped content model - MapPolicy could only ever check
# manage_platform/manage_platform_settings globally (see the matching policy
# fix in this same PR). Adds the column and best-effort backfills existing
# rows from their mappable's own platform_id, where the mappable model has
# one; falls back to the host platform when it doesn't.
class AddPlatformIdToBetterTogetherGeographyMaps < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def up
    unless column_exists?(:better_together_geography_maps, :platform_id)
      add_reference :better_together_geography_maps, :platform,
                    type: :uuid, null: true,
                    foreign_key: { to_table: :better_together_platforms },
                    index: true
    end

    backfill_platform_id
  end

  def down
    remove_reference :better_together_geography_maps, :platform, foreign_key: true if column_exists?(
      :better_together_geography_maps, :platform_id
    )
  end

  private

  def backfill_platform_id
    backfill_from_mappable
    backfill_remaining_from_host_platform
  end

  def backfill_from_mappable
    mappable_types = execute(
      'SELECT DISTINCT mappable_type FROM better_together_geography_maps WHERE mappable_type IS NOT NULL'
    ).map { |row| row['mappable_type'] }

    mappable_types.each { |mappable_type| backfill_for_mappable_type(mappable_type) }
  end

  def backfill_for_mappable_type(mappable_type)
    klass = mappable_type.safe_constantize
    return unless klass&.table_exists? && klass.column_names.include?('platform_id')

    mappable_table = klass.quoted_table_name

    execute(<<~SQL.squish)
      UPDATE better_together_geography_maps
      SET platform_id = mappables.platform_id
      FROM #{mappable_table} mappables
      WHERE better_together_geography_maps.mappable_id = mappables.id
        AND better_together_geography_maps.mappable_type = #{quote(mappable_type)}
        AND better_together_geography_maps.platform_id IS NULL
        AND mappables.platform_id IS NOT NULL
    SQL
  end

  def backfill_remaining_from_host_platform
    host_platform_id = execute(
      'SELECT id FROM better_together_platforms WHERE host = true LIMIT 1'
    ).first&.fetch('id', nil)
    return unless host_platform_id

    execute(<<~SQL.squish)
      UPDATE better_together_geography_maps
      SET platform_id = #{quote(host_platform_id)}
      WHERE platform_id IS NULL
    SQL
  end
end

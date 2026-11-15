# frozen_string_literal: true

# Slugs belong to a platform, and uniqueness is enforced per platform.
#
# The old unique index (slug, sluggable_type, scope, locale) never enforced anything: `scope` is
# NULL on every row and Postgres treats NULLs as distinct inside a unique index. The new index
# folds a missing platform to the nil uuid so it does enforce, for platform-less rows as well.
# Existing duplicates (usually history rows) are copied to a backup table, and the newest row per
# key is kept, which is the row the history finder already prefers.
class AddPlatformToFriendlyIdSlugs < ActiveRecord::Migration[7.2]
  TABLE = :friendly_id_slugs
  OLD_INDEX = 'index_friendly_id_slugs_unique'
  NEW_INDEX = 'idx_friendly_id_slugs_unique_per_platform'
  BACKUP_TABLE = 'friendly_id_slugs_deduplicated_backup'
  NIL_UUID = '00000000-0000-0000-0000-000000000000'
  KEY_SQL = "COALESCE(platform_id, '#{NIL_UUID}'::uuid), sluggable_type, slug, locale".freeze

  def up
    return unless table_exists?(TABLE)

    add_column TABLE, :platform_id, :uuid unless column_exists?(TABLE, :platform_id)
    add_index TABLE, :platform_id unless index_exists?(TABLE, :platform_id)
    backfill_platform_ids
    deduplicate_rows
    remove_index TABLE, name: OLD_INDEX if index_name_exists?(TABLE, OLD_INDEX)
    return if index_name_exists?(TABLE, NEW_INDEX)

    execute "CREATE UNIQUE INDEX #{NEW_INDEX} ON #{TABLE} (#{KEY_SQL})"
  end

  def down
    return unless table_exists?(TABLE)

    remove_index TABLE, name: NEW_INDEX if index_name_exists?(TABLE, NEW_INDEX)
    unless index_name_exists?(TABLE, OLD_INDEX)
      add_index TABLE, %i[slug sluggable_type scope locale], unique: true, name: OLD_INDEX
    end
    remove_index TABLE, :platform_id if index_exists?(TABLE, :platform_id)
    remove_column TABLE, :platform_id if column_exists?(TABLE, :platform_id)
  end

  private

  def backfill_platform_ids
    select_values("SELECT DISTINCT sluggable_type FROM #{TABLE}").each do |type|
      table = sluggable_table(type)
      next unless table && table_exists?(table) && column_exists?(table, :platform_id)

      execute <<~SQL.squish
        UPDATE #{TABLE} s SET platform_id = t.platform_id
        FROM #{quote_table_name(table)} t
        WHERE s.sluggable_type = #{quote(type)} AND s.sluggable_id = t.id
          AND s.platform_id IS NULL AND t.platform_id IS NOT NULL
      SQL
    end
  end

  def sluggable_table(type)
    klass = type.safe_constantize
    klass.respond_to?(:base_class) ? klass.base_class.table_name : nil
  rescue StandardError
    nil
  end

  def deduplicate_rows
    duplicates = <<~SQL.squish
      SELECT id FROM (
        SELECT id, ROW_NUMBER() OVER (PARTITION BY #{KEY_SQL} ORDER BY id DESC) AS rank FROM #{TABLE}
      ) ranked WHERE rank > 1
    SQL
    return if select_value("SELECT 1 FROM (#{duplicates}) d LIMIT 1").blank?

    unless table_exists?(BACKUP_TABLE)
      execute "CREATE TABLE #{BACKUP_TABLE} AS SELECT * FROM #{TABLE} WHERE false"
    end
    execute "INSERT INTO #{BACKUP_TABLE} SELECT * FROM #{TABLE} WHERE id IN (#{duplicates})"
    execute "DELETE FROM #{TABLE} WHERE id IN (#{duplicates})"
  end
end

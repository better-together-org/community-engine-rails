# frozen_string_literal: true

# RichTextLink.platform_id has never been set by any code path — RichTextLinkIdentifier
# never passed it. rich_text_record can be any model with has_rich_text content, so
# rather than a fixed type list this discovers the distinct owner types actually present
# and joins per-type, falling back to host for rows whose owner has no platform_id
# column (or has been destroyed).
class BackfillPlatformIdForMetricsRichTextLinks < ActiveRecord::Migration[7.2]
  def up
    return unless column_exists?(:better_together_metrics_rich_text_links, :platform_id)

    distinct_owner_types.each { |type| backfill_from_owner_type(type) }

    host_platform_id = execute(
      'SELECT id FROM better_together_platforms WHERE host = TRUE LIMIT 1'
    ).first&.fetch('id')

    if host_platform_id
      execute <<~SQL
        UPDATE better_together_metrics_rich_text_links
        SET platform_id = #{quote(host_platform_id)}
        WHERE platform_id IS NULL
      SQL
    end

    remaining_null = execute(
      'SELECT count(*) FROM better_together_metrics_rich_text_links WHERE platform_id IS NULL'
    ).first&.fetch('count').to_i

    if remaining_null.zero?
      change_column_null :better_together_metrics_rich_text_links, :platform_id, false
    else
      say "Skipping NOT NULL: #{remaining_null} rich_text_links rows still have a NULL platform_id — leaving nullable."
    end
  end

  def down
    return unless column_exists?(:better_together_metrics_rich_text_links, :platform_id)

    change_column_null :better_together_metrics_rich_text_links, :platform_id, true
  end

  private

  def distinct_owner_types
    execute(
      'SELECT DISTINCT rich_text_record_type FROM better_together_metrics_rich_text_links ' \
      'WHERE rich_text_record_type IS NOT NULL'
    ).map { |row| row['rich_text_record_type'] }
  end

  def backfill_from_owner_type(type)
    klass = type.safe_constantize
    return unless klass&.column_names&.include?('platform_id')

    table = klass.table_name

    execute <<~SQL.squish
      UPDATE better_together_metrics_rich_text_links rtl
      SET platform_id = owner.platform_id
      FROM #{table} owner
      WHERE rtl.rich_text_record_type = #{quote(type)}
        AND rtl.rich_text_record_id = owner.id
        AND rtl.platform_id IS NULL
        AND owner.platform_id IS NOT NULL
    SQL
  end
end

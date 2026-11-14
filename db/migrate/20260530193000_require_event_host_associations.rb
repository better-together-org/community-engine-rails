# frozen_string_literal: true

class RequireEventHostAssociations < ActiveRecord::Migration[7.2]
  TABLE = :better_together_event_hosts
  REQUIRED_COLUMNS = %i[event_id host_type host_id].freeze

  def up
    return unless table_exists?(TABLE)

    remove_unrepairable_rows
    REQUIRED_COLUMNS.each { |column| require_column(column) }
  end

  def down
    return unless table_exists?(TABLE)

    REQUIRED_COLUMNS.each do |column|
      change_column_null TABLE, column, true if column_exists?(TABLE, column)
    end
  end

  private

  def remove_unrepairable_rows
    quoted_table = quote_table_name(TABLE)
    null_checks = REQUIRED_COLUMNS
                  .select { |column| column_exists?(TABLE, column) }
                  .map { |column| "#{quote_column_name(column)} IS NULL" }

    return if null_checks.empty?

    where_clause = null_checks.join(' OR ')
    unrepairable_count = select_value(<<~SQL.squish).to_i
      SELECT COUNT(*) FROM #{quoted_table} WHERE #{where_clause}
    SQL

    if unrepairable_count.positive?
      say "Removing #{unrepairable_count} #{TABLE} row(s) with a missing required " \
          "column (#{REQUIRED_COLUMNS.join(', ')}) — these predate the association " \
          'being required and cannot be repaired automatically.'
    end

    execute <<~SQL.squish
      DELETE FROM #{quoted_table}
      WHERE #{where_clause}
    SQL
  end

  def require_column(column)
    return unless column_exists?(TABLE, column)
    return unless column_nullable?(column)

    change_column_null TABLE, column, false
  end

  def column_nullable?(column)
    connection.columns(TABLE).find { |definition| definition.name == column.to_s }&.null
  end
end

# frozen_string_literal: true

# Quota usage and reservation rows were written without a platform of their own, so a row written from a background
# job took whichever platform the code fell back to (the host) whatever its owner's platform was. This gives every row
# its owner's platform. Safe to run again: it only touches rows that have none, or the wrong one.
class BackfillBetterTogetherQuotaPlatformIds < ActiveRecord::Migration[7.2]
  TABLES = %w[better_together_quota better_together_quota_usages better_together_quota_reservations better_together_quota_balances].freeze

  def up
    TABLES.each do |table|
      next unless table_exists?(table) && column_exists?(table, :platform_id)

      backfill_from_owner(table)
    end
    backfill_balances_from_quota
  end

  def down; end

  private

  # People and communities carry their platform; a platform owns itself.
  def backfill_from_owner(table)
    return unless column_exists?(table, :owner_type)

    execute(<<~SQL.squish)
      UPDATE #{table} t SET platform_id = o.platform_id
      FROM better_together_people o
      WHERE t.owner_type = 'BetterTogether::Person' AND t.owner_id = o.id AND o.platform_id IS NOT NULL AND t.platform_id IS DISTINCT FROM o.platform_id
    SQL
    execute(<<~SQL.squish)
      UPDATE #{table} t SET platform_id = o.platform_id
      FROM better_together_communities o
      WHERE t.owner_type = 'BetterTogether::Community' AND t.owner_id = o.id AND o.platform_id IS NOT NULL AND t.platform_id IS DISTINCT FROM o.platform_id
    SQL
    execute("UPDATE #{table} SET platform_id = owner_id WHERE owner_type = 'BetterTogether::Platform' AND platform_id IS DISTINCT FROM owner_id")
  end

  def backfill_balances_from_quota
    return unless table_exists?(:better_together_quota_balances) && column_exists?(:better_together_quota_balances, :platform_id)

    execute(<<~SQL.squish)
      UPDATE better_together_quota_balances b SET platform_id = q.platform_id
      FROM better_together_quota q WHERE b.quota_id = q.id AND q.platform_id IS NOT NULL AND b.platform_id IS DISTINCT FROM q.platform_id
    SQL
  end
end

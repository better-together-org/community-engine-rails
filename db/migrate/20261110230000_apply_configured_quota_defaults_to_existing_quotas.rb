# frozen_string_literal: true

# Brings every existing media_storage quota owned by a LOCAL owner (a local platform,
# or a person/community on one) to the currently configured default
# (config/quota_defaults.yml plus any host-app override, via Quotas::Defaults).
# Quotas for external owners (federated peers, OAuth providers and people/communities
# mirrored from them) are left untouched and only counted in the log: they should
# never have had a quota. Per-owner QuotaGrant overrides are separate records and are
# not touched. Idempotent: re-running just re-applies the same values.
class ApplyConfiguredQuotaDefaultsToExistingQuotas < ActiveRecord::Migration[7.2]
  QUOTA_TYPE = 'media_storage'
  OWNERS = {
    'person' => %w[BetterTogether::Person better_together_people],
    'community' => %w[BetterTogether::Community better_together_communities]
  }.freeze

  def up
    return unless table_exists?(:better_together_quotas) && table_exists?(:better_together_platforms)
    return unless column_exists?(:better_together_platforms, :external)

    BetterTogether::Quotas::Defaults.reset!
    updated = OWNERS.sum { |kind, (owner_type, table)| update_owner_quotas(kind, owner_type, table) }
    updated += update_platform_quotas

    say "updated #{updated} local #{QUOTA_TYPE} quota(s); left #{external_quota_count} external-owner quota(s) untouched"
  end

  def down; end

  private

  def limit_for(kind)
    BetterTogether::Quotas::Defaults.yaml_value(QUOTA_TYPE, kind)
  end

  def update_owner_quotas(kind, owner_type, owner_table)
    limit = limit_for(kind)
    return 0 if limit.nil? || !table_exists?(owner_table) || !column_exists?(owner_table, :platform_id)

    update_quotas(owner_type, limit, <<~SQL.squish)
      SELECT o.id FROM #{owner_table} o
      LEFT JOIN better_together_platforms p ON p.id = o.platform_id
      WHERE p.id IS NULL OR p.external = FALSE
    SQL
  end

  def update_platform_quotas
    limit = limit_for('platform')
    return 0 if limit.nil?

    update_quotas('BetterTogether::Platform', limit, 'SELECT id FROM better_together_platforms WHERE external = FALSE')
  end

  def update_quotas(owner_type, limit, owner_ids_sql)
    execute(<<~SQL.squish).cmd_tuples
      UPDATE better_together_quotas
      SET "limit" = #{Integer(limit)}, updated_at = CURRENT_TIMESTAMP
      WHERE quota_type = #{quote(QUOTA_TYPE)}
        AND owner_type = #{quote(owner_type)}
        AND owner_id IN (#{owner_ids_sql})
    SQL
  end

  def external_quota_count
    total = select_value("SELECT COUNT(*) FROM better_together_quotas WHERE quota_type = #{quote(QUOTA_TYPE)}").to_i
    total - local_quota_total
  end

  def local_quota_total
    OWNERS.sum do |_kind, (owner_type, table)|
      next 0 unless table_exists?(table) && column_exists?(table, :platform_id)

      select_value(<<~SQL.squish).to_i
        SELECT COUNT(*) FROM better_together_quotas q
        WHERE q.quota_type = #{quote(QUOTA_TYPE)} AND q.owner_type = #{quote(owner_type)}
          AND q.owner_id IN (SELECT o.id FROM #{table} o LEFT JOIN better_together_platforms p ON p.id = o.platform_id
                             WHERE p.id IS NULL OR p.external = FALSE)
      SQL
    end + select_value(<<~SQL.squish).to_i
      SELECT COUNT(*) FROM better_together_quotas
      WHERE quota_type = #{quote(QUOTA_TYPE)} AND owner_type = 'BetterTogether::Platform'
        AND owner_id IN (SELECT id FROM better_together_platforms WHERE external = FALSE)
    SQL
  end
end

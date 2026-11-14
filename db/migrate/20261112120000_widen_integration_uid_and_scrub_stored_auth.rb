# frozen_string_literal: true

# OpenID Connect `sub` values can be 255 characters, and the raw provider payload kept in the plain
# `auth` jsonb column held access/refresh/id tokens that the encrypted token columns exist to protect.
class WidenIntegrationUidAndScrubStoredAuth < ActiveRecord::Migration[7.1]
  TABLE = :better_together_person_platform_integrations
  SENSITIVE = %w[credentials id_token refresh_token access_token token secret].freeze

  def up
    return unless table_exists?(TABLE)

    change_column TABLE, :uid, :string, limit: 255, null: false, default: '' if column_exists?(TABLE, :uid)
    scrub_stored_auth if column_exists?(TABLE, :auth)
  end

  def down
    # Widening is harmless to keep and scrubbed tokens cannot be restored.
  end

  private

  def scrub_stored_auth
    # Top-level keys, plus the same keys inside `extra`; idempotent.
    execute <<~SQL.squish
      UPDATE #{TABLE}
      SET auth = ((auth - ARRAY[#{SENSITIVE.map { |k| "'#{k}'" }.join(',')}])
                  #{extra_clause})
      WHERE auth IS NOT NULL
    SQL
  end

  def extra_clause
    "|| CASE WHEN jsonb_typeof(auth->'extra') = 'object' " \
      "THEN jsonb_build_object('extra', (auth->'extra') - ARRAY[#{SENSITIVE.map { |k| "'#{k}'" }.join(',')}]) " \
      "ELSE '{}'::jsonb END"
  end
end

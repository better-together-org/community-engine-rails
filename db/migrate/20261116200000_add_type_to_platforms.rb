# frozen_string_literal: true

# Adds the STI type column to platforms and classifies existing rows.
#
# Classification, first match wins, only for rows whose type is still NULL (safe to rerun):
#   host row                                  -> OperatorPlatform
#   external, OAuth/OIDC provider identifier  -> OauthPlatform
#   other external rows (federated peers)     -> FederatedPlatform
#   everything else                           -> HostedPlatform
#
# The provider identifiers are a snapshot of what the OAuth code creates (never read from app constants), so the
# migration keeps its meaning if those constants change. Only columns present on older host-app schemas are used.
# The column stays nullable: a NULL type loads as the base Platform until creation sites set a type.
class AddTypeToPlatforms < ActiveRecord::Migration[7.2]
  TABLE = :better_together_platforms
  INDEX = 'index_better_together_platforms_on_type'
  OAUTH_IDENTIFIERS = %w[github google facebook linkedin openid_connect].freeze
  OIDC_PATTERN = '^oidc-[0-9a-f]{16}$'

  def up
    return unless table_exists?(TABLE)

    add_column TABLE, :type, :string unless column_exists?(TABLE, :type)
    add_index TABLE, :type, name: INDEX unless index_name_exists?(TABLE, INDEX)
    classify_rows
  end

  def down
    return unless table_exists?(TABLE) && column_exists?(TABLE, :type)

    remove_index TABLE, name: INDEX if index_name_exists?(TABLE, INDEX)
    remove_column TABLE, :type
  end

  private

  # Reads the legacy external boolean when it still exists, else the locality that replaced it.
  def remote_condition
    column_exists?(TABLE, :external) ? 'external IS TRUE' : "locality = 'remote'"
  end

  def classify_rows
    remote = remote_condition
    quoted = OAUTH_IDENTIFIERS.map { |identifier| connection.quote(identifier) }.join(', ')
    execute <<~SQL.squish
      UPDATE #{TABLE} SET type = CASE
        WHEN host IS TRUE THEN 'BetterTogether::OperatorPlatform'
        WHEN #{remote} AND (identifier IN (#{quoted}) OR identifier ~ '#{OIDC_PATTERN}')
          THEN 'BetterTogether::OauthPlatform'
        WHEN #{remote} THEN 'BetterTogether::FederatedPlatform'
        ELSE 'BetterTogether::HostedPlatform'
      END
      WHERE type IS NULL
    SQL
  end
end

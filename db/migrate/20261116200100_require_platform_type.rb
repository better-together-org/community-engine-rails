# frozen_string_literal: true

# Every platform now has a type. Classifies any row still missing one (rows created between the previous
# migration and this one), then makes the column required. New rows get their type from the subclass they are
# built as, or from Platform#infer_type.
#
# Self-contained on purpose: host apps copy engine migrations under new file names, so a migration must never
# require another migration file by its original name. The classification mirrors AddTypeToPlatforms.
class RequirePlatformType < ActiveRecord::Migration[7.2]
  TABLE = :better_together_platforms
  OAUTH_IDENTIFIERS = %w[github google facebook linkedin openid_connect].freeze
  OIDC_PATTERN = '^oidc-[0-9a-f]{16}$'

  def up
    return unless table_exists?(TABLE) && column_exists?(TABLE, :type)

    classify_rows
    change_column_null TABLE, :type, false
  end

  def down
    return unless table_exists?(TABLE) && column_exists?(TABLE, :type)

    change_column_null TABLE, :type, true
  end

  private

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

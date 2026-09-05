# frozen_string_literal: true

class BackfillExpiredFeatureAccessGrants < ActiveRecord::Migration[7.2]
  def up
    execute <<~SQL.squish
      UPDATE better_together_feature_access_grants
      SET revoked_at = COALESCE(revoked_at, expires_at),
          updated_at = CURRENT_TIMESTAMP
      WHERE revoked_at IS NULL
        AND expires_at IS NOT NULL
        AND expires_at <= CURRENT_TIMESTAMP
    SQL
  end

  def down; end
end

# frozen_string_literal: true

module BetterTogether
  # Purges expired and revoked federation access tokens from the database.
  # Tokens accumulate with every OAuth exchange — this job keeps the table
  # from growing unboundedly.  Designed to run daily (see sidekiq_scheduler.yml).
  #
  # Only removes tokens that have been expired/revoked for at least 1 hour
  # to give in-flight requests a grace window.
  class FederationAccessTokenPurgeJob < ApplicationJob
    queue_as :maintenance

    GRACE_PERIOD = 1.hour

    def perform
      stale_cutoff = GRACE_PERIOD.ago

      deleted_count = BetterTogether::FederationAccessToken
                      .where(
                        'expires_at < ? OR (revoked_at IS NOT NULL AND revoked_at < ?)',
                        stale_cutoff,
                        stale_cutoff
                      )
                      .delete_all

      Rails.logger.info "[FederationAccessTokenPurgeJob] Deleted #{deleted_count} stale token(s)"
    end
  end
end

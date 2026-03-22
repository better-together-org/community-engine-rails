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

      tbl = BetterTogether::FederationAccessToken.arel_table
      deleted_count = BetterTogether::FederationAccessToken
                      .where(
                        tbl[:expires_at].lt(stale_cutoff)
                          .or(tbl[:revoked_at].not_eq(nil).and(tbl[:revoked_at].lt(stale_cutoff)))
                      )
                      .delete_all

      Rails.logger.info "[FederationAccessTokenPurgeJob] Deleted #{deleted_count} stale token(s)"
    end
  end
end

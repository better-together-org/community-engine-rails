# frozen_string_literal: true

module BetterTogether
  module Billing
    module PayExtensions
      # Keeps what a subscription gives in step with the subscription, whoever changes it: Community Engine's own
      # renewals, or Pay syncing a processor's webhook. When a column that decides access changes, the work is
      # queued (after the change is committed), so it can be retried and can never undo the change itself. A
      # subscription with no terms (not one of ours to give anything for) is skipped by the job.
      module EntitlementSync
        extend ActiveSupport::Concern

        ACCESS_COLUMNS = %i[status current_period_end ends_at trial_ends_at pause_starts_at].freeze

        included do
          after_commit :enqueue_entitlement_sync, on: %i[create update], if: :entitlement_relevant_change?
        end

        private

        def entitlement_relevant_change?
          ACCESS_COLUMNS.any? { |column| saved_change_to_attribute?(column) }
        end

        def enqueue_entitlement_sync
          BetterTogether::Billing::SyncEntitlementJob.perform_later(id)
        end
      end
    end
  end
end

# frozen_string_literal: true

module BetterTogether
  module Billing
    # Current-state grant record answering "is this holder entitled to X" —
    # one row per (holder, entitlement_key, source), refreshed in place
    # whenever its source resyncs (mirrors how Billing::Subscription itself
    # is refreshed via find_or_initialize_by + save!, not appended to).
    # Unlike Billing::BenefitCredit's append-only signed-quantity ledger,
    # this models on/off or tiered access state that can change without any
    # new event (a Stripe dunning retry, a grace-period clock elapsing).
    class Entitlement < ApplicationRecord
      self.table_name = 'better_together_billing_entitlements'

      STATUSES = %w[active revoked expired].freeze

      belongs_to :holder, polymorphic: true
      belongs_to :source, polymorphic: true, optional: true
      belongs_to :billing_plan, class_name: 'BetterTogether::Billing::Plan', optional: true
      belongs_to :granted_by, polymorphic: true, optional: true

      validates :entitlement_key, inclusion: { in: -> { BetterTogether::EntitlementRegistry.keys } }
      validates :holder_type,
                inclusion: { in: -> { BetterTogether::Billing::EntitlementHolder.included_in_models.map(&:name) } }
      validates :status, inclusion: { in: STATUSES }
      validates :granted_at, presence: true

      scope :for_holder_and_key, ->(holder, key) { where(holder:, entitlement_key: key) }
      scope :current, lambda {
        # rubocop:disable BetterTogether/NoRawSqlInQueries -- NULL-or-future timestamp comparison has no clean Arel/hash equivalent
        where(status: 'active').where('expires_at IS NULL OR expires_at > ?', Time.current)
        # rubocop:enable BetterTogether/NoRawSqlInQueries
      }

      class << self
        # rubocop:disable Metrics/ParameterLists -- all 6 are meaningful, independent grant attributes
        def grant!(holder:, entitlement_key:, source: nil, billing_plan: nil, expires_at: nil, granted_by: nil)
          record = find_or_initialize_by(holder:, entitlement_key:, source:)
          record.assign_attributes(
            status: 'active',
            billing_plan:,
            expires_at:,
            granted_by:,
            granted_at: record.granted_at || Time.current,
            revoked_at: nil
          )
          record.save!
          record
        end
        # rubocop:enable Metrics/ParameterLists

        def revoke!(holder:, entitlement_key:, source: nil)
          record = find_by(holder:, entitlement_key:, source:)
          return if record.blank? || record.status == 'revoked'

          record.update!(status: 'revoked', revoked_at: Time.current)
          record
        end
      end
    end
  end
end

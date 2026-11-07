# frozen_string_literal: true

module BetterTogether
  module Billing
    # What was actually applied for an entitlement: the ownership link. `owned` says whether the entitlement
    # MADE the thing (a membership, a feature grant) or only found it already there; only what it owns is ever
    # taken away. The kind and parameters are copied from the plan so editing a plan later never loses track of
    # what was applied, and `grant_key` names the grant (unique per entitlement) so applying it twice is harmless.
    # A quota allowance has no record behind it: it is the `amount` of a `quota_type`.
    class EntitlementGrant < ApplicationRecord
      include PlatformBound
      include ParentBound

      self.table_name = 'better_together_billing_entitlement_grants'

      STATUSES = %w[applied released].freeze
      # What an applied grant can point at, by class name: nothing is resolved from a string the plan supplied.
      APPLIED_TYPES = %w[BetterTogether::PersonPlatformMembership BetterTogether::PersonCommunityMembership BetterTogether::FeatureAccessGrant].freeze

      belongs_to :entitlement, class_name: 'BetterTogether::Billing::Entitlement', inverse_of: :grants, optional: false
      belongs_to :applied, polymorphic: true, optional: true

      attr_readonly :entitlement_id, :grant_key, :kind

      validates :grant_key, presence: true, uniqueness: { scope: :entitlement_id }
      validates :kind, inclusion: { in: ->(_) { Entitlements::Registry.kinds } }
      validates :status, inclusion: { in: STATUSES }
      validates :applied_type, inclusion: { in: APPLIED_TYPES }, allow_nil: true
      validates :amount, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

      scope :applied, -> { where(status: 'applied') }
      scope :allowances, -> { where(kind: 'quota_allowance') }

      def applied? = status == 'applied'

      def release!
        update!(status: 'released', released_at: Time.current)
      end

      private

      def billing_parent = entitlement
    end
  end
end

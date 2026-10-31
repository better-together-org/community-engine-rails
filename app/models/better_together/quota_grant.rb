# frozen_string_literal: true

module BetterTogether
  # An admin-issued override of a Quota's limit for one owner+type, optionally
  # time-boxed. Multiple grants may exist for the same owner+type over time (each
  # one an audit record of a decision); the active one with the highest limit wins
  # (see Quota#effective_limit). Nothing in this phase reads effective_limit to make
  # a blocking decision - Quotas.check! stays permissive regardless - this is schema
  # and data entry only, ahead of the usage data enforcement will eventually need.
  class QuotaGrant < PlatformRecord
    belongs_to :owner, polymorphic: true
    belongs_to :granted_by, polymorphic: true, optional: true

    validates :quota_type, presence: true, inclusion: { in: ->(_record) { BetterTogether::Quotas::Type.keys } }
    validates :limit, presence: true, numericality: { greater_than_or_equal_to: 0 }
    validates :granted_by_type, inclusion: { in: BetterTogether::QuotaUsage::ACTOR_TYPES }, allow_nil: true
    validate :owner_is_quota_owner

    scope :active, -> { where(expires_at: nil).or(where(QuotaGrant.arel_table[:expires_at].gt(Time.current))) }
    scope :for_owner_and_type, ->(owner, quota_type) { where(owner:, quota_type:) }

    private

    # Same direct module check as Quota#owner_is_quota_owner, not Owner.included_in_models.
    def owner_is_quota_owner
      return if owner.is_a?(BetterTogether::Quotas::Owner)

      errors.add(:owner_type, :inclusion, value: owner_type)
    end
  end
end

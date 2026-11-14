# frozen_string_literal: true

module BetterTogether
  # A time-limited hold against a Quota's balance, settled or released as the
  # reserved action completes or fails. Phase 5a creates these rows (so the amount is
  # recorded) but never reaps expired ones and never reads `reserved` to make a
  # blocking decision, which arrives with enforcement in a later phase.
  class QuotaReservation < PlatformRecord
    belongs_to :quota
    belongs_to :subject, polymorphic: true, optional: true
    belongs_to :actor, polymorphic: true, optional: true
    belongs_to :owner, polymorphic: true

    enum :status, { held: 'held', settled: 'settled', released: 'released', expired: 'expired' },
         prefix: true, default: 'held'

    validates :quota_type, presence: true
    validates :amount, presence: true, numericality: { only_integer: true }
    validates :period_key, presence: true
    validates :expires_at, presence: true
    validates :idempotency_key, presence: true, uniqueness: true
    validates :actor_type, inclusion: { in: BetterTogether::QuotaUsage::ACTOR_TYPES }, allow_nil: true
  end
end

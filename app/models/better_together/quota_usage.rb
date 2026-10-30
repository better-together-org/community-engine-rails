# frozen_string_literal: true

module BetterTogether
  # Append-only usage ledger entry. Never updated or destroyed after creation; a
  # correction is a new row (a reversal, amount negated), never an edit to an existing
  # one. See BetterTogether::Quotas for the only intended write path (.reserve!/.settle!/
  # .reverse!); do not create rows directly outside that facade.
  class QuotaUsage < PlatformRecord
    # The same closed set Authorship uses for its polymorphic author: who can act is
    # engine-defined, not a host-app extension point, so this is a hardcoded array
    # rather than an included_in_models scan.
    ACTOR_TYPES = ['BetterTogether::Person', 'BetterTogether::Robot'].freeze

    belongs_to :quota
    belongs_to :subject, polymorphic: true, optional: true
    belongs_to :actor, polymorphic: true, optional: true
    belongs_to :owner, polymorphic: true

    # Not a Rails enum: an enum value named "reverse" would generate a class method
    # that collides with ActiveRecord::Relation#reverse.
    EVENTS = %w[reserve settle reverse backfill].freeze

    validates :quota_type, presence: true
    validates :amount, presence: true, numericality: { only_integer: true }
    validates :period_key, presence: true
    validates :idempotency_key, presence: true, uniqueness: true
    validates :event, inclusion: { in: EVENTS }
    validates :actor_type, inclusion: { in: ACTOR_TYPES }, allow_nil: true

    # readonly? true once persisted blocks save/update (raises ActiveRecord::ReadOnlyRecord).
    # destroy is not reliably blocked by readonly? alone across Rails versions, so it is
    # also explicitly halted below rather than relying on that side effect.
    def readonly?
      persisted?
    end

    before_destroy { throw(:abort) }
  end
end

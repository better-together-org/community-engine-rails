# frozen_string_literal: true

module BetterTogether
  # A usage limit for one owner (Person, Community, or Platform) and one quota type.
  # Rows are created lazily from each type's declared defaults the first time usage is
  # attributed to an owner, following the same lazy-row pattern as CommentConfig.
  class Quota < PlatformRecord
    # No table_name override needed: this app's inflections leave "quota".pluralize
    # unchanged, so Rails' own default table-name inference already lands on
    # "better_together_quota" (singular), matching the migration. Verified directly
    # against ActiveRecord::Base.table_name, not just the raw Inflector call.
    belongs_to :owner, polymorphic: true

    # :restrict_with_exception, not :destroy: quota_usages is an append-only ledger;
    # nothing should ever be able to delete usage history as a side effect of deleting
    # the quota row above it (and nothing in this phase deletes Quota rows at all).
    has_many :quota_usages, dependent: :restrict_with_exception
    has_many :quota_reservations, dependent: :destroy
    has_many :quota_balances, dependent: :destroy

    enum :period, { cumulative: 'cumulative', monthly: 'monthly', daily: 'daily' },
         prefix: true, default: 'cumulative'
    enum :status, { active: 'active', suspended: 'suspended' },
         prefix: true, default: 'active'
    # off/shadow/soft/hard. Phase 5a never evaluates this as blocking: Quotas.check!
    # is hardcoded permissive regardless of the value stored here. Reversibility is
    # a separate, type-level flag (Quotas::Type#reversible?), not stored per-row,
    # since it is a fact about the resource being metered, not this specific quota.
    enum :enforcement_mode, { off: 'off', shadow: 'shadow', soft: 'soft', hard: 'hard' },
         prefix: true, default: 'shadow'

    validates :quota_type, presence: true, inclusion: { in: ->(_record) { BetterTogether::Quotas::Type.keys } }
    validates :limit, presence: true, numericality: { greater_than_or_equal_to: 0 }
    validates :owner_type, inclusion: {
      in: ->(_record) { BetterTogether::Quotas::Owner.included_in_models.map(&:name) }
    }
    validates :owner_id, uniqueness: { scope: %i[owner_type quota_type] }
  end
end

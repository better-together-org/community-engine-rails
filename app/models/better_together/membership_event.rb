# frozen_string_literal: true

module BetterTogether
  # Append-only history of a platform or community membership: who changed what, when and why.
  # Rows are written by MembershipLifecycle and are never updated.
  class MembershipEvent < ApplicationRecord
    EVENT_TYPES = %w[created activated pending suspended reinstated ended role_changed removed].freeze

    belongs_to :membership, polymorphic: true, optional: true
    belongs_to :member, class_name: 'BetterTogether::Person'
    belongs_to :actor, class_name: 'BetterTogether::Person', optional: true
    belongs_to :platform, class_name: 'BetterTogether::Platform', optional: true

    validates :event_type, inclusion: { in: EVENT_TYPES }
    validates :joinable_type, :joinable_id, presence: true

    before_update { throw :abort }
    scope :recent_first, -> { order(created_at: :desc) }
  end
end

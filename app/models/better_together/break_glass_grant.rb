# frozen_string_literal: true

module BetterTogether
  # A time-limited, audited grant letting one person read one private record they could not otherwise read.
  # Read only. It becomes usable after a delay (so the affected member can be told), expires on its own and
  # can be revoked at any time. State is derived from the timestamps, so no job has to flip it.
  class BreakGlassGrant < PlatformRecord
    DEFAULT_DELAY = 24.hours
    MAX_DURATION = 7.days
    DEFAULT_DURATION = 24.hours
    MIN_REASON_LENGTH = 20
    # Allow-list of record types a grant may point at. Never constantize from input.
    SUBJECT_TYPES = %w[BetterTogether::Community].freeze
    STATUSES = %w[requested revoked].freeze

    belongs_to :subject, polymorphic: true
    belongs_to :grantee, class_name: 'BetterTogether::Person'
    belongs_to :requested_by, class_name: 'BetterTogether::Person'
    belongs_to :approved_by, class_name: 'BetterTogether::Person', optional: true
    has_many :events, class_name: 'BetterTogether::BreakGlassEvent', inverse_of: :break_glass_grant,
                      dependent: nil

    validates :status, inclusion: { in: STATUSES }
    validates :subject_type, inclusion: { in: SUBJECT_TYPES }
    validates :reason, presence: true, length: { minimum: MIN_REASON_LENGTH }
    validates :reason_code, presence: true, if: :emergency?
    validates :available_at, :expires_at, presence: true
    validate :expiry_within_limits

    before_destroy { throw :abort }

    scope :current, lambda {
      now = Time.current
      where(status: 'requested').where(arel_table[:available_at].lteq(now)).where(arel_table[:expires_at].gt(now))
    }

    def pending?
      status == 'requested' && available_at.future?
    end

    def revoked?
      status == 'revoked'
    end

    def expired?
      expires_at <= Time.current
    end

    # The only question a policy asks.
    def active_now?
      status == 'requested' && !pending? && !expired?
    end

    def state
      return :revoked if revoked?
      return :expired if expired?

      pending? ? :pending : :active
    end

    private

    def expiry_within_limits
      return if available_at.blank? || expires_at.blank?

      errors.add(:expires_at, :greater_than, count: available_at) if expires_at <= available_at
      errors.add(:expires_at, :less_than, count: latest_expiry) if expires_at > latest_expiry
    end

    def latest_expiry
      available_at + MAX_DURATION
    end
  end
end

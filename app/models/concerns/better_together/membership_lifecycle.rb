# frozen_string_literal: true

module BetterTogether
  # Lifecycle shared by platform and community memberships: start and end dates, the suspended and ended
  # states, where a membership came from, and an append-only event trail.
  #
  # A membership is current only when its status is active and now sits inside starts_at..ends_at. Ending a
  # membership keeps the row as history; the unique key ignores ended rows so the role can be given again.
  module MembershipLifecycle
    extend ActiveSupport::Concern

    SOURCES = %w[direct registration invitation request trusted_domain entitlement wizard backfill].freeze
    STEWARD_ROLE_IDENTIFIERS = %w[platform_steward platform_manager community_governance_council].freeze

    included do
      validates :source, inclusion: { in: SOURCES }
      validate :ends_after_starts

      has_many :membership_events, as: :membership, class_name: 'BetterTogether::MembershipEvent',
                                   dependent: nil

      after_create :record_created_event
      after_update :record_lifecycle_events
      before_destroy :record_removed_event, prepend: true

      scope :current, -> { where(current_condition) }
      scope :history, -> { where(status: 'ended').or(where.not(ends_at: nil).where(arel_table[:ends_at].lteq(Time.current))) }
    end

    class_methods do
      # The current rule as an Arel node, for subqueries and joins that cannot use the scope.
      def current_condition
        now = Time.current
        arel_table[:status].eq('active').and(started_before(now)).and(not_ended_by(now))
      end

      def started_before(time)
        arel_table[:starts_at].eq(nil).or(arel_table[:starts_at].lteq(time))
      end

      def not_ended_by(time)
        arel_table[:ends_at].eq(nil).or(arel_table[:ends_at].gt(time))
      end
    end

    # True while the membership grants anything: active, started and not past its end date.
    def current?
      active_status? && (starts_at.nil? || starts_at <= Time.current) && (ends_at.nil? || ends_at > Time.current)
    end

    def end!(reason: nil, actor: Current.person, at: Time.current)
      guard_last_steward!
      update!(status: 'ended', ends_at: at, ended_reason: reason, lifecycle_actor: actor)
    end

    def suspend!(reason: nil, actor: Current.person)
      guard_last_steward!
      update!(status: 'suspended', ended_reason: reason, lifecycle_actor: actor)
    end

    def reinstate!(actor: Current.person)
      update!(status: 'active', ends_at: nil, ended_reason: nil, lifecycle_actor: actor)
    end

    # True when ending or suspending this row would leave the member with no current membership
    # on the same platform or community, so they keep only the public view.
    def sole_current_membership?
      current? && !self.class.current.where(member_id:, joinable_id:).where.not(id:).exists?
    end

    def last_steward?
      return false unless STEWARD_ROLE_IDENTIFIERS.include?(role&.identifier)

      self.class.current.where(joinable_id:, role_id:).where.not(id:).none?
    end

    attr_writer :lifecycle_actor
    # Set by a hard purge of a person, which erases their history rather than recording it.
    attr_accessor :skip_lifecycle_audit

    private

    def active_status?
      status == 'active'
    end

    def lifecycle_actor
      @lifecycle_actor || Current.person
    end

    def guard_last_steward!
      return unless last_steward?

      errors.add(:base, :last_steward)
      raise ActiveRecord::RecordInvalid, self
    end

    def ends_after_starts
      return if starts_at.blank? || ends_at.blank? || ends_at > starts_at

      errors.add(:ends_at, :after_starts_at)
    end

    def record_created_event
      record_event('created', to_status: status, to_role_id: role_id)
    end

    def record_removed_event
      return if skip_lifecycle_audit

      record_event('removed', from_status: status, from_role_id: role_id)
    end

    def record_lifecycle_events
      if saved_change_to_status?
        record_event(status_event_type, from_status: status_before_last_save, to_status: status,
                                        reason: ended_reason)
      end
      return unless saved_change_to_role_id?

      record_event('role_changed', from_role_id: role_id_before_last_save, to_role_id: role_id)
    end

    def status_event_type
      { 'active' => status_before_last_save == 'pending' ? 'activated' : 'reinstated',
        'suspended' => 'suspended', 'ended' => 'ended', 'pending' => 'pending' }.fetch(status)
    end

    def record_event(event_type, **attrs)
      BetterTogether::MembershipEvent.create!(
        membership: self, joinable_type: joinable_type_for_event, joinable_id:, member_id:,
        actor: lifecycle_actor, platform_id: joinable_platform_id, event_type:, **attrs
      )
    end

    def joinable_type_for_event
      joinable.class.name
    end
  end
end

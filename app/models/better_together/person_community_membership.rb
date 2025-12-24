# frozen_string_literal: true

module BetterTogether
  # Used to represent a person's connection to a community with a specific role
  class PersonCommunityMembership < ApplicationRecord
    include Membership

    membership member_class: 'BetterTogether::Person',
               joinable_class: 'BetterTogether::Community'

    STATUS_LEVELS = {
      pending: 'pending',
      active: 'active'
    }.freeze

    enum :status, STATUS_LEVELS, default: 'pending'

    after_create_commit :notify_member_of_creation_if_active
    before_update :store_old_role_for_notification
    after_update_commit :notify_member_of_role_update
    after_update_commit :notify_member_of_activation
    before_destroy :store_member_data_for_notification
    before_destroy :cleanup_related_notifications
    after_destroy_commit :notify_member_of_removal
    after_destroy_commit :schedule_notification_cleanup

    scope :pending, -> { where(status: 'pending') }
    scope :active, -> { where(status: 'active') }

    def activate!
      update!(status: 'active')
    end

    private

    def notify_member_of_creation_if_active
      MembershipNotificationService.new(self).notify_creation_if_active
    end

    def notify_member_of_activation
      MembershipNotificationService.new(self).notify_activation
    end

    def store_old_role_for_notification
      @old_role_for_notification = role_id_was ? BetterTogether::Role.find(role_id_was) : nil if role_id_changed?
    end

    def notify_member_of_role_update
      MembershipNotificationService.new(self).notify_role_update(@old_role_for_notification)
    end

    # rubocop:todo Metrics/PerceivedComplexity
    # rubocop:todo Metrics/AbcSize
    # rubocop:todo Lint/CopDirectiveSyntax
    def store_member_data_for_notification # rubocop:todo Metrics/CyclomaticComplexity, Metrics/AbcSize, Metrics/PerceivedComplexity
      # rubocop:enable Lint/CopDirectiveSyntax
      @member_data_for_notification = {
        email: member&.email,
        name: member&.name,
        locale: member&.locale,
        time_zone: member&.time_zone,
        role: role,
        role_name: role&.name,
        joinable: joinable,
        joinable_name: joinable&.name || joinable&.to_s
      }
    end
    # rubocop:enable Metrics/AbcSize
    # rubocop:enable Metrics/PerceivedComplexity

    def notify_member_of_removal
      MembershipNotificationService.new(self).notify_removal(@member_data_for_notification)
    end

    def cleanup_related_notifications
      # Store the information needed for cleanup before the record is destroyed
      @cleanup_info = { record_type: self.class.name, record_id: id }
    end

    def schedule_notification_cleanup
      return unless @cleanup_info

      BetterTogether::CleanupNotificationsJob.perform_later(
        record_type: @cleanup_info[:record_type],
        record_id: @cleanup_info[:record_id]
      )
    end
  end
end

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
      return unless member && active?

      BetterTogether::MembershipCreatedNotifier.with(membership: self, record: self).deliver_later(member)
    end

    def notify_member_of_activation
      return unless saved_change_to_status? && active?
      return unless member

      # Send the creation notification when membership becomes active
      BetterTogether::MembershipCreatedNotifier.with(membership: self, record: self).deliver_later(member)
    end

    def store_old_role_for_notification
      @old_role_for_notification = role_id_was ? BetterTogether::Role.find(role_id_was) : nil if role_id_changed?
    end

    def notify_member_of_role_update
      return unless @old_role_for_notification && @old_role_for_notification != role
      return unless member

      # Send in-app notification
      BetterTogether::MembershipUpdatedNotifier.with(
        membership: self,
        record: self,
        old_role: @old_role_for_notification,
        new_role: role
      ).deliver_later(member)

      # Send email notification if email is present
      return unless member.email.present?

      BetterTogether::MembershipMailer.with(
        recipient: {
          email: member.email,
          locale: member.locale || I18n.default_locale,
          time_zone: member.time_zone || Time.zone
        },
        joinable: joinable,
        old_role: @old_role_for_notification,
        new_role: role,
        member_name: member.name
      ).updated.deliver_later
    end

    def store_member_data_for_notification
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

    def notify_member_of_removal
      return unless @member_data_for_notification
      return unless member

      # Notify the member about their removal
      BetterTogether::MembershipRemovedNotifier.with(
        member_data: @member_data_for_notification,
        record: @member_data_for_notification[:joinable] # Use joinable as the record
      ).deliver_later(member)

      # Also send email notification to the removed member if email is present
      return unless @member_data_for_notification[:email].present?

      data = @member_data_for_notification
      BetterTogether::MembershipMailer.with(
        recipient: {
          email: data[:email],
          locale: data[:locale] || I18n.default_locale,
          time_zone: data[:time_zone] || Time.zone
        },
        joinable: data[:joinable],
        role: data[:role],
        member_name: data[:name]
      ).removed.deliver_later
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

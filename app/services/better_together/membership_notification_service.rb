# frozen_string_literal: true

module BetterTogether
  # Service class to handle all membership-related notifications
  # Extracts notification logic from PersonCommunityMembership and PersonPlatformMembership models
  class MembershipNotificationService
    def initialize(membership)
      @membership = membership
    end

    def notify_creation_if_active
      return unless @membership.active?
      return unless @membership.member

      BetterTogether::MembershipCreatedNotifier.with(
        record: @membership,
        membership: @membership
      ).deliver_later(@membership.member)
    end

    def notify_activation
      return unless @membership.saved_change_to_status?(from: 'pending', to: 'active')
      return unless @membership.member

      BetterTogether::MembershipCreatedNotifier.with(
        record: @membership,
        membership: @membership
      ).deliver_later(@membership.member)
    end

    def notify_role_update(old_role)
      return unless old_role && old_role != @membership.role
      return unless @membership.member

      send_in_app_role_notification(old_role)
      send_email_role_notification(old_role) if email_notifications_enabled?
    end

    def notify_removal(member_data)
      return unless member_data && @membership.member

      send_in_app_removal_notification(member_data)
      send_email_removal_notification(member_data) if member_data[:email].present?
    end

    private

    def send_in_app_role_notification(old_role)
      BetterTogether::MembershipUpdatedNotifier.with(
        record: @membership,
        membership: @membership,
        old_role: old_role,
        new_role: @membership.role
      ).deliver_later(@membership.member)
    end

    def send_email_role_notification(old_role)
      BetterTogether::MembershipMailer.with(
        recipient: recipient_data,
        joinable: @membership.joinable,
        old_role: old_role,
        new_role: @membership.role,
        member_name: @membership.member.name
      ).updated.deliver_later
    end

    def send_in_app_removal_notification(member_data)
      # Ensure timezone is serializable
      serializable_data = member_data.dup
      serializable_data[:time_zone] = serializable_data[:time_zone]&.to_s if serializable_data[:time_zone]

      BetterTogether::MembershipRemovedNotifier.with(
        record: member_data[:joinable],
        member_data: serializable_data
      ).deliver_later(@membership.member)
    end

    def send_email_removal_notification(member_data)
      BetterTogether::MembershipMailer.with(
        recipient: {
          email: member_data[:email],
          locale: member_data[:locale] || I18n.default_locale,
          time_zone: (member_data[:time_zone] || Time.zone).to_s
        },
        joinable: member_data[:joinable],
        role: member_data[:role],
        member_name: member_data[:name]
      ).removed.deliver_later
    end

    def recipient_data
      {
        email: @membership.member.email,
        locale: @membership.member.locale || I18n.default_locale,
        time_zone: (@membership.member.time_zone || Time.zone).to_s
      }
    end

    def email_notifications_enabled?
      @membership.member.email.present?
    end
  end
end

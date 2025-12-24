# frozen_string_literal: true

module BetterTogether
  # Sends email notifications when a membership is created
  class MembershipMailer < ApplicationMailer # rubocop:todo Metrics/ClassLength
    include BetterTogether::RolesHelper

    helper BetterTogether::RolesHelper

    def created
      setup_created_vars
      return if invalid_recipient?

      setup_common_vars
      setup_created_permission_summary
      setup_locale_and_timezone

      mail(
        to: @recipient.email,
        subject: I18n.t(
          'better_together.membership_mailer.created.subject',
          joinable_name: @joinable_name,
          joinable_type: @joinable_type
        )
      )
    end

    # Sends notification when a membership role is updated
    def updated
      setup_updated_vars
      process_recipient
      return if invalid_recipient?

      setup_common_vars
      setup_updated_permission_summaries
      setup_locale_and_timezone

      mail(
        to: @recipient.email,
        subject: I18n.t(
          'better_together.membership_mailer.updated.subject',
          joinable_name: @joinable_name,
          joinable_type: @joinable_type
        )
      )
    end

    # Sends notification when a membership is removed
    def removed
      setup_removed_vars
      process_recipient
      return if invalid_recipient?

      setup_common_vars
      setup_removed_permission_summary
      setup_locale_and_timezone

      mail(
        to: @recipient.email,
        subject: I18n.t(
          'better_together.membership_mailer.removed.subject',
          joinable_name: @joinable_name,
          joinable_type: @joinable_type
        )
      )
    end

    private

    def setup_created_vars
      @membership = params[:membership]
      @recipient = params[:recipient] || @membership&.member
      @joinable = @membership&.joinable
      @role = @membership&.role
    end

    def setup_updated_vars
      @recipient = params[:recipient]
      @joinable = params[:joinable]
      @old_role = params[:old_role]
      @new_role = params[:new_role]
      @member_name = params[:member_name]
    end

    def setup_removed_vars
      @recipient = params[:recipient]
      @joinable = params[:joinable]
      @role = params[:role]
      @member_name = params[:member_name]
    end

    def process_recipient
      return unless @recipient.is_a?(Hash)

      recipient_struct = Struct.new(:email, :locale, :time_zone, keyword_init: true)
      @recipient = recipient_struct.new(@recipient)
    end

    def invalid_recipient?
      @recipient.blank? || @recipient.email.blank?
    end

    def setup_common_vars
      @joinable_name = @joinable.respond_to?(:name) ? @joinable.name : @joinable.to_s
      @joinable_type = @joinable&.model_name&.human
      @joinable_url = joinable_url(@joinable, locale: @recipient.locale)
    end

    def setup_created_permission_summary
      @permission_summary = build_permission_summary(@role)
    end

    def setup_updated_permission_summaries
      @old_permission_summary = build_permission_summary(@old_role)
      @new_permission_summary = build_permission_summary(@new_role)
    end

    def setup_removed_permission_summary
      @permission_summary = build_permission_summary(@role)
    end

    def build_permission_summary(role, limit: 6)
      return { labels: [], remaining: 0 } unless role.present?

      role_permission_summary(role, limit: limit)
    end

    def setup_locale_and_timezone
      self.locale = @recipient.locale
      self.time_zone = @recipient.time_zone
    end

    def joinable_url(joinable, locale:)
      return unless joinable&.persisted?

      case joinable
      when BetterTogether::Platform
        BetterTogether::Engine.routes.url_helpers.platform_url(joinable, locale: locale)
      when BetterTogether::Community
        BetterTogether::Engine.routes.url_helpers.community_url(joinable, locale: locale)
      else
        BetterTogether::Engine.routes.url_helpers.polymorphic_url(joinable, locale: locale)
      end
    end
  end
end

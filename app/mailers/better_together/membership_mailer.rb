# frozen_string_literal: true

module BetterTogether
  # Sends email notifications when a membership is created
  class MembershipMailer < ApplicationMailer
    include BetterTogether::RolesHelper

    helper BetterTogether::RolesHelper

    # rubocop:todo Metrics/PerceivedComplexity
    # rubocop:todo Metrics/MethodLength
    # rubocop:todo Metrics/AbcSize
    # rubocop:todo Lint/CopDirectiveSyntax
    def created # rubocop:todo Metrics/CyclomaticComplexity, Metrics/AbcSize, Metrics/MethodLength, Metrics/PerceivedComplexity
      # rubocop:enable Lint/CopDirectiveSyntax
      @membership = params[:membership]
      @recipient = params[:recipient] || @membership&.member
      @joinable = @membership&.joinable
      @role = @membership&.role

      return if @recipient.blank? || @recipient.email.blank?

      @joinable_name = @joinable.respond_to?(:name) ? @joinable.name : @joinable.to_s
      @joinable_type = @joinable&.model_name&.human
      @permission_summary = @role.present? ? role_permission_summary(@role, limit: 6) : { labels: [], remaining: 0 }
      @joinable_url = joinable_url(@joinable, locale: @recipient.locale)

      self.locale = @recipient.locale
      self.time_zone = @recipient.time_zone

      mail(
        to: @recipient.email,
        subject: I18n.t(
          'better_together.membership_mailer.created.subject',
          joinable_name: @joinable_name,
          joinable_type: @joinable_type
        )
      )
    end
    # rubocop:enable Metrics/AbcSize
    # rubocop:enable Metrics/MethodLength
    # rubocop:enable Metrics/PerceivedComplexity

    # Sends notification when a membership role is updated
    def updated
      @recipient = params[:recipient]
      @joinable = params[:joinable]
      @old_role = params[:old_role]
      @new_role = params[:new_role]
      @member_name = params[:member_name]

      # Handle both hash and object recipient formats
      if @recipient.is_a?(Hash)
        @recipient = OpenStruct.new(@recipient)
      end

      return if @recipient.blank? || @recipient.email.blank?

      @joinable_name = @joinable.respond_to?(:name) ? @joinable.name : @joinable.to_s
      @joinable_type = @joinable&.model_name&.human
      @old_permission_summary = @old_role.present? ? role_permission_summary(@old_role, limit: 6) : { labels: [], remaining: 0 }
      @new_permission_summary = @new_role.present? ? role_permission_summary(@new_role, limit: 6) : { labels: [], remaining: 0 }
      @joinable_url = joinable_url(@joinable, locale: @recipient.locale)

      self.locale = @recipient.locale
      self.time_zone = @recipient.time_zone

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
      @recipient = params[:recipient]
      @joinable = params[:joinable]
      @role = params[:role]
      @member_name = params[:member_name]

      # Handle both hash and object recipient formats
      if @recipient.is_a?(Hash)
        @recipient = OpenStruct.new(@recipient)
      end

      return if @recipient.blank? || @recipient.email.blank?

      @joinable_name = @joinable.respond_to?(:name) ? @joinable.name : @joinable.to_s
      @joinable_type = @joinable&.model_name&.human
      @permission_summary = @role.present? ? role_permission_summary(@role, limit: 6) : { labels: [], remaining: 0 }
      @joinable_url = joinable_url(@joinable, locale: @recipient.locale)

      self.locale = @recipient.locale
      self.time_zone = @recipient.time_zone

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

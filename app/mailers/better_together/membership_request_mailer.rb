# frozen_string_literal: true

module BetterTogether
  # Sends reviewer and requester emails for membership request decisions.
  class MembershipRequestMailer < ApplicationMailer
    RecipientData = Struct.new(:email, :locale, :time_zone, :name)

    def submitted
      setup_request_context
      return if invalid_recipient?

      mail(
        to: @recipient.email,
        subject: I18n.t(
          'better_together.membership_request_mailer.submitted.subject',
          community_name: @community_name
        )
      )
    end

    def declined
      setup_request_context
      @decision_actor_name = params[:decision_actor]&.name
      return if invalid_recipient?

      mail(
        to: @recipient.email,
        subject: I18n.t(
          'better_together.membership_request_mailer.declined.subject',
          community_name: @community_name
        )
      )
    end

    private

    def setup_request_context
      @membership_request = params[:membership_request]
      @recipient = normalize_recipient(params[:recipient])
      assign_community_context
      assign_requestor_context
      assign_recipient_context
      assign_delivery_context
    end

    def normalize_recipient(raw_recipient)
      return raw_recipient if raw_recipient.respond_to?(:email)
      return if raw_recipient.blank?

      recipient_hash = raw_recipient.transform_keys(&:to_sym)
      RecipientData.new(
        recipient_hash[:email],
        recipient_hash[:locale],
        recipient_hash[:time_zone],
        recipient_hash[:name]
      )
    end

    def invalid_recipient?
      @recipient.blank? || @recipient.email.blank?
    end

    def assign_community_context
      @community = @membership_request&.target if @membership_request&.target.is_a?(BetterTogether::Community)
      @community_name = @community&.name || default_community_name
    end

    def assign_requestor_context
      @requestor_name = requestor_name
      @requestor_email = @membership_request&.requestor_email.presence || @membership_request&.creator&.email
      @request_description = @membership_request&.description
    end

    def assign_recipient_context
      @recipient_name = @recipient&.name.presence || @requestor_name || @recipient&.email
    end

    def assign_delivery_context
      @review_url = params[:review_url].presence || fallback_review_url
      self.locale = @recipient&.locale || I18n.locale || I18n.default_locale
      self.time_zone = @recipient&.time_zone || Time.zone
    end

    def requestor_name
      @membership_request&.requestor_name.presence ||
        @membership_request&.creator&.name ||
        @membership_request&.requestor_email
    end

    def default_community_name
      I18n.t('better_together.membership_requests.fields.target', default: 'Community')
    end

    def fallback_review_url
      return unless @community&.persisted?

      BetterTogether::Engine.routes.url_helpers.community_url(@community, locale:)
    end
  end
end

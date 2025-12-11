# frozen_string_literal: true

module BetterTogether
  # Base class for invitation notifiers that provides common functionality
  # for sending notifications across different invitation types
  class InvitationNotifierBase < ApplicationNotifier
    deliver_by :action_cable, channel: 'BetterTogether::NotificationsChannel', message: :build_message,
                              queue: :notifications

    required_param :invitation

    def invitation = params[:invitation]
    def invitable = params[:invitable] || invitation&.invitable

    def locale
      params[:invitation]&.locale || I18n.locale || I18n.default_locale
    end

    def build_message(_notification)
      # Pass the invitable as the notification url object so views can
      # link to the resource record (consistent with other notifiers that pass
      # domain objects like agreement/request).
      { title:, body:, url: invitation.url_for_review }
    end

    def email_params(_notification)
      # Include the invitation and the invitable so mailers and views
      # have the full context without needing to resolve the invitation.
      { invitation: params[:invitation], invitable: }
    end

    protected

    # Template methods to be implemented by subclasses
    def title
      I18n.with_locale(locale) do
        I18n.t(title_i18n_key, **title_i18n_vars, default: default_title)
      end
    end

    def body
      I18n.with_locale(locale) do
        I18n.t(body_i18n_key, **body_i18n_vars, default: default_body)
      end
    end

    private

    # Template methods to be implemented by subclasses
    def title_i18n_key
      raise NotImplementedError, "#{self.class} must implement #title_i18n_key"
    end

    def body_i18n_key
      raise NotImplementedError, "#{self.class} must implement #body_i18n_key"
    end

    def title_i18n_vars
      raise NotImplementedError, "#{self.class} must implement #title_i18n_vars"
    end

    def body_i18n_vars
      raise NotImplementedError, "#{self.class} must implement #body_i18n_vars"
    end

    def default_title
      raise NotImplementedError, "#{self.class} must implement #default_title"
    end

    def default_body
      raise NotImplementedError, "#{self.class} must implement #default_body"
    end
  end
end

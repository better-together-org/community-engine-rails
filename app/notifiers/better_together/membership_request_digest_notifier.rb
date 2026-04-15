# frozen_string_literal: true

module BetterTogether
  # Collapses a burst of new membership requests into one review digest per reviewer.
  class MembershipRequestDigestNotifier < ApplicationNotifier
    deliver_by :action_cable, channel: 'BetterTogether::NotificationsChannel', message: :build_message,
                              queue: :notifications
    deliver_by :email, mailer: 'BetterTogether::MembershipRequestMailer', method: :digest, params: :email_params,
                       queue: :mailers do |config|
      config.if = -> { recipient_has_email? && email_delivery_enabled? }
    end

    required_param :community, :membership_request_ids, :request_count, :requestor_names, :review_url, :send_email

    validates :record, presence: true

    def community
      params[:community] || record
    end

    def locale
      recipient&.locale || I18n.locale || I18n.default_locale
    end

    def membership_requests
      BetterTogether::Joatu::MembershipRequest.where(id: params[:membership_request_ids]).order(created_at: :desc)
    end

    def title
      I18n.with_locale(locale) do
        I18n.t(
          'better_together.notifications.membership_request_digest.title',
          count: request_count,
          community_name: community_name,
          default: '%<count>s membership requests need review for %<community_name>s'
        )
      end
    end

    def body
      I18n.with_locale(locale) do
        I18n.t(
          'better_together.notifications.membership_request_digest.body',
          requestors: requestor_summary,
          count: request_count,
          community_name: community_name,
          default: '%<requestors>s submitted %<count>s membership requests for %<community_name>s'
        )
      end
    end

    def build_message(_notification)
      { title:, body:, url: review_path }
    end

    def email_params(_notification)
      {
        community:,
        recipient:,
        membership_request_ids: params[:membership_request_ids],
        request_count:,
        requestor_names: Array(params[:requestor_names]),
        review_url: params[:review_url]
      }
    end

    notification_methods do
      delegate :title, :body, :review_path, :email_params, to: :event

      def recipient_has_email?
        recipient.respond_to?(:email) && recipient.email.present? &&
          (!recipient.respond_to?(:notification_preferences) ||
           recipient.notification_preferences.fetch('notify_by_email', true))
      end

      def email_delivery_enabled?
        event.params.with_indifferent_access[:send_email]
      end
    end

    private

    def review_path
      return unless community&.persisted?

      BetterTogether::Engine.routes.url_helpers.community_membership_requests_path(
        community,
        locale:
      )
    end

    def request_count
      params[:request_count].to_i
    end

    def requestor_summary
      names = Array(params[:requestor_names]).reject(&:blank?)
      if names.empty?
        return I18n.t('better_together.notifications.membership_request_digest.unknown_requestors',
                      default: 'New applicants')
      end

      return names.first if names.one?

      I18n.t(
        'better_together.notifications.membership_request_digest.requestor_summary',
        first_requestor: names.first,
        additional_count: names.size - 1,
        default: '%<first_requestor>s and %<additional_count>s others'
      )
    end

    def community_name
      community&.name || I18n.t('better_together.membership_requests.fields.target', default: 'Community')
    end
  end
end

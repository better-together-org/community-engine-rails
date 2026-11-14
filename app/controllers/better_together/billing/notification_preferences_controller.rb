# frozen_string_literal: true

module BetterTogether
  module Billing
    # How the signed-in person is told about billing: whether notices that are not critical are emailed. Notices
    # that need action (a failed payment, a hold about to expire) are always shown in the app and emailed.
    class NotificationPreferencesController < ApplicationController
      include OwnerScoped

      after_action :verify_authorized

      def show
        authorize BetterTogether::Billing::Order, :index?
        @critical_kinds = Notifications::Catalog::KINDS.keys.select { |kind| Notifications::Catalog.critical?(kind) && buyer_kind?(kind) }
      end

      def update
        authorize BetterTogether::Billing::Order, :index?
        current_user.person.update!(notify_billing_by_email: params[:notify_billing_by_email] == '1')
        redirect_to billing_notification_preferences_path(locale: I18n.locale),
                    notice: t('better_together.billing.notification_preferences.saved')
      end

      private

      def buyer_kind?(kind) = Notifications::Catalog.audiences(kind).include?(:buyer)
    end
  end
end

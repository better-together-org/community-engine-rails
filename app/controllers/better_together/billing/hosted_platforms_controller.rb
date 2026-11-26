# frozen_string_literal: true

module BetterTogether
  module Billing
    # The host's steward sees every hosted platform: which billing agreements it has accepted, which modes are on, and
    # whether its billing is suspended. Suspending pauses billing on that platform at once and keeps all its data; resuming
    # restores what its agreements allow. Each is recorded as a billing event.
    class HostedPlatformsController < ApplicationController
      include OwnerScoped

      before_action :set_platform, only: %i[suspend resume]
      after_action :verify_authorized

      def index
        authorize BetterTogether::Billing::HostedAccount, :index?, policy_class: HostedBillingPolicy
        @platforms = HostedBilling.hosted_platforms.includes(:billing_hosted_account)
        @agreements = HostedBilling::AGREEMENT_FOR.keys.index_with { |mode| HostedBilling.agreement(mode) }
      end

      def suspend
        authorize BetterTogether::Billing::HostedAccount, :suspend?, policy_class: HostedBillingPolicy
        reason = params[:reason].to_s.strip.first(500)
        return redirect_with(alert: t('better_together.billing.hosted_platforms.reason_required')) if reason.blank?

        HostedBilling.suspend!(platform: @platform, by: current_user.person, reason:)
        redirect_with(notice: t('better_together.billing.hosted_platforms.suspended'))
      end

      def resume
        authorize BetterTogether::Billing::HostedAccount, :resume?, policy_class: HostedBillingPolicy
        HostedBilling.resume!(platform: @platform, by: current_user.person)
        redirect_with(notice: t('better_together.billing.hosted_platforms.resumed'))
      end

      private

      # Reachable as soon as the host has billing switched on, whether or not a method is enabled yet.
      def billing_available?
        BetterTogether::Billing::Configuration.requested? && BetterTogether::Billing::Configuration.ready? && billing_owner&.host?
      end

      # Platforms are addressed by their slug in URLs (see Identifier#to_param).
      def set_platform = @platform = HostedBilling.hosted_platforms.friendly.find(params[:id])

      def redirect_with(flash) = redirect_to(billing_hosted_platforms_path(locale: I18n.locale), **flash)
    end
  end
end

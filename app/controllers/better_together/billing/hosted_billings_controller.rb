# frozen_string_literal: true

module BetterTogether
  module Billing
    # A hosted platform's steward reads the host's billing agreements and accepts them for the platform, one at a time:
    # first the hosted platform billing agreement, then (to take cash, cheque or e-transfer) the hosted local billing
    # agreement. The merchant onboarding agreement can be accepted too, though that mode is not available yet.
    #
    # What is accepted is recorded with the platform as the participant and the steward's id in the evidence, through the
    # shared agreement recorder. Nothing here turns billing on by itself: it only unlocks what the agreements cover.
    class HostedBillingsController < ApplicationController
      include OwnerScoped

      before_action :set_agreement, only: :create
      after_action :verify_authorized

      def show
        authorize BetterTogether::Billing::HostedAccount, :show?, policy_class: HostedBillingPolicy
        @modes = HostedBilling::AGREEMENT_FOR.keys
        @agreements = @modes.index_with { |mode| HostedBilling.agreement(mode) }
      end

      def create
        authorize BetterTogether::Billing::HostedAccount, :accept?, policy_class: HostedBillingPolicy
        problem = acceptance_problem
        return refuse(problem) if problem

        HostedBilling.accept!(platform: billing_owner, mode: @mode, person: current_user.person, request:)
        redirect_to billing_hosted_billing_path(locale: I18n.locale), notice: t('better_together.billing.hosted_billing.accepted')
      end

      private

      # Reachable before billing is on for the platform; the host never uses it.
      def billing_available?
        BetterTogether::Billing::Configuration.requested? && BetterTogether::Billing::Configuration.ready? && !billing_owner&.host?
      end

      def set_agreement
        @mode = HostedBilling::AGREEMENT_FOR.keys.find { |mode| mode.to_s == params[:mode].to_s }
        raise ActiveRecord::RecordNotFound unless @mode

        @agreement = HostedBilling.agreement(@mode)
      end

      def acceptance_problem
        return :not_in_force unless HostedBilling.in_force?(@agreement)
        return :needs_billing_first unless @mode == :billing || HostedBilling.accepted?(billing_owner, :billing)

        :accept_box unless params[helpers.agreement_acceptance_param_name(@agreement)] == '1'
      end

      def refuse(reason)
        redirect_to billing_hosted_billing_path(locale: I18n.locale), alert: t("better_together.billing.hosted_billing.refused.#{reason}")
      end
    end
  end
end

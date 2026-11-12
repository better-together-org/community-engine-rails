# frozen_string_literal: true

module BetterTogether
  module Billing
    # A person's own subscriptions that Community Engine renews: what they pay, when it renews, each period
    # and its invoice, and cancelling, resuming and accepting changed terms. Only the payer's own are ever
    # loaded, so another person's subscription is a 404 whatever id is sent.
    class SubscriptionsController < ApplicationController
      include OwnerScoped

      before_action :set_term, except: :index
      after_action :verify_authorized

      def index
        authorize BetterTogether::Billing::SubscriptionTerm, :own?
        @terms = own_terms.includes(:plan, pay_subscription: :customer).order(created_at: :desc)
      end

      def show
        authorize @term
        @gate = agreement_gate if @term.periods.exists?(status: 'needs_agreement')
        @plan_options = Subscriptions::ChangePlan.options(@term)
      end

      def cancel
        authorize @term
        Subscriptions::Cancel.call(term: @term, by: current_user.person)
        redirect_to billing_subscription_path(@term, locale: I18n.locale), notice: t('better_together.billing.subscriptions.cancelled')
      end

      def resume
        authorize @term
        Subscriptions::Resume.call(term: @term)
        redirect_to billing_subscription_path(@term, locale: I18n.locale), notice: t('better_together.billing.subscriptions.resumed')
      rescue Subscriptions::Resume::Refused
        redirect_to billing_subscription_path(@term, locale: I18n.locale), alert: t('better_together.billing.subscriptions.cannot_resume')
      end

      # Choose another plan from the next period.
      def change_plan
        authorize @term
        plan = billing_owner.billing_plans.sold_by_platform.find(params[:plan_id])
        params[:when] == 'now' ? change_now(plan) : change_next(plan)
      rescue Subscriptions::ChangePlan::Refused => e
        redirect_to show_path, alert: t("better_together.billing.subscriptions.plan_change_refused.#{e.code}")
      end

      def withdraw_plan_change
        authorize @term, :change_plan?
        Subscriptions::ChangePlan.withdraw(term: @term)
        redirect_to show_path, notice: t('better_together.billing.subscriptions.plan_change_withdrawn')
      end

      # The payer accepts the agreements that changed; the renewal invoice is made at once.
      def accept_agreements
        authorize @term
        gate = agreement_gate
        return refuse_agreements unless accepted_everything_missing?(gate)

        gate.accept!(method: 'agreement_review', context: { request: })
        Subscriptions::GenerateRenewal.call(term: @term)
        redirect_to billing_subscription_path(@term, locale: I18n.locale), notice: t('better_together.billing.subscriptions.terms_accepted')
      rescue Checkout::AgreementGate::NotReady
        refuse_agreements
      end

      private

      def show_path = billing_subscription_path(@term, locale: I18n.locale)

      # Moves now: a cheaper plan at once (with credit back), a dearer one once the invoice for the difference is paid.
      def change_next(plan)
        Subscriptions::ChangePlan.request(term: @term, plan:)
        redirect_to show_path, notice: t('better_together.billing.subscriptions.plan_change_saved')
      end

      def change_now(plan)
        outcome = Subscriptions::ChangePlan.now(term: @term, plan:)
        amount = helpers.billing_amount(outcome.amount_cents, @term.currency)
        key = { invoiced: 'plan_change_invoiced', credited: 'plan_change_credited' }.fetch(outcome.mode, 'plan_change_done')
        target = outcome.mode == :invoiced ? billing_order_path(outcome.order, locale: I18n.locale) : show_path
        redirect_to target, notice: t("better_together.billing.subscriptions.#{key}", amount:)
      end

      def own_terms
        billing_owner.billing_subscription_terms.local
                     .where(pay_customers: { owner_type: BetterTogether::Person.name, owner_id: current_user.person.id })
                     .joins(pay_subscription: :customer)
      end

      def set_term
        @term = own_terms.find(params[:id])
      end

      def agreement_gate
        Checkout::AgreementGate.new(platform: billing_owner, purpose: 'subscription', signer: current_user.person, purchasables: [@term.plan],
                                    payment_method: @term.payment_method)
      end

      def accepted_everything_missing?(gate)
        ticked = Array(params[:accepted_agreement_ids]).map(&:to_s)
        gate.missing.all? { |agreement| ticked.include?(agreement.id) }
      end

      def refuse_agreements
        redirect_to billing_subscription_path(@term, locale: I18n.locale), alert: t('better_together.billing.subscriptions.accept_all')
      end
    end
  end
end

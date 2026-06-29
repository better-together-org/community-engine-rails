# frozen_string_literal: true

module BetterTogether
  # Person-owned billing entry points for Stripe checkout and portal access.
  class PersonBillingsController < ApplicationController # rubocop:todo Metrics/ClassLength
    before_action :authenticate_user!
    before_action :set_person
    before_action :authorize_person
    before_action :authorize_merchant_account_management, only: %i[merchant_onboarding refresh_merchant_account]
    after_action :verify_authorized

    def show
      @checkout_sync_result = sync_checkout_session if valid_checkout_session_id?
      @billing_plans = available_billing_plans
      @billing_subscription = current_billing_subscription
      @merchant_account = current_merchant_account
      @billing_alert_events = billing_alert_events
      @billing_alert_summary = billing_alert_summary
      @last_billing_event = last_billing_event
      @sponsored_communities = sponsored_communities
    end

    def checkout
      redirect_to checkout_session_for(find_billing_plan).url, allow_other_host: true
    rescue ActiveRecord::RecordNotFound
      redirect_to person_billing_path(@person, locale: I18n.locale),
                  alert: t('better_together.billing.plan_not_found', default: 'That billing plan is not available.'),
                  status: :see_other
    end

    # rubocop:disable Metrics/AbcSize
    def portal
      portal_session = @person.set_payment_processor(:stripe).billing_portal(
        return_url: person_billing_url(@person, locale: I18n.locale)
      )
      current_billing_subscription&.clear_portal_access_failure!

      redirect_to portal_session.url, allow_other_host: true
    rescue StandardError => e
      current_billing_subscription&.record_portal_access_failure!(message: e.message)
      redirect_to person_billing_path(@person, locale: I18n.locale),
                  alert: t(
                    'better_together.billing.portal_unavailable',
                    default: 'The billing portal is not available yet: %<message>s',
                    message: ERB::Util.html_escape(e.message)
                  ),
                  status: :see_other
    end
    # rubocop:enable Metrics/AbcSize

    def reconcile
      BetterTogether::Billing::ReconcileStripeBillableOwnerBillingJob.perform_later(@person.class.name, @person.id)

      redirect_to person_billing_path(@person, locale: I18n.locale),
                  notice: t(
                    'better_together.billing.reconciliation_enqueued',
                    default: 'A Stripe reconciliation job was queued for this billing account.'
                  ),
                  status: :see_other
    end

    def merchant_onboarding
      redirect_to merchant_onboarding_result.url, allow_other_host: true
    rescue BetterTogether::Billing::MerchantAccounts::StripeConnect::CreateOnboardingLink::OnboardingDisabledError => e
      redirect_to_billing_with_alert(e.message)
    rescue StandardError => e
      redirect_to_billing_with_alert(merchant_onboarding_unavailable_message(e))
    end

    def refresh_merchant_account
      merchant_refresh_service.call(merchant_account: current_merchant_account, owner: @person)

      redirect_to_billing_with_notice(merchant_refresh_complete_message)
    rescue StandardError => e
      redirect_to_billing_with_alert(merchant_refresh_failed_message(e))
    end

    def replay_event
      replay_result = billing_event_replay_service.call(
        billing_event: replayable_billing_event,
        requested_by: current_user
      )

      redirect_to person_billing_path(@person, locale: I18n.locale),
                  flash: replay_event_flash(replay_result),
                  status: :see_other
    rescue ActiveRecord::RecordNotFound
      redirect_to_billing_with_alert(replay_event_not_found_message)
    end

    private

    def set_person
      @person = BetterTogether::Person.friendly.find(params[:person_id])
    end

    def authorize_person
      authorize @person, :update?
    end

    def authorize_merchant_account_management
      authorize @person, :manage_merchant_account?
    end

    def available_billing_plans
      BetterTogether::Billing::Plan.active.order(:amount_cents, :name).select do |plan|
        plan.launch_ready_for_hosted_billing? && plan.eligible_for?(@person)
      end
    end

    def checkout_metadata(billing_plan)
      BetterTogether::Billing::OwnershipResolver.build_metadata(billing_plan:)
    end

    def find_billing_plan
      available_billing_plans.find { |plan| plan.id == params[:billing_plan_id] } || raise(ActiveRecord::RecordNotFound)
    end

    def checkout_session_for(billing_plan)
      payment_processor.checkout(**checkout_options(billing_plan))
    end

    def checkout_options(billing_plan)
      metadata = checkout_metadata(billing_plan)

      {
        mode: billing_plan.recurring? ? 'subscription' : 'payment',
        line_items: [{ price: billing_plan.stripe_price_id, quantity: 1 }],
        success_url: billing_success_url,
        cancel_url: billing_cancel_url,
        allow_promotion_codes: true,
        client_reference_id: @person.id,
        metadata:,
        subscription_data: subscription_checkout_data(billing_plan, metadata)
      }
    end

    def subscription_checkout_data(billing_plan, metadata)
      return unless billing_plan.recurring?

      { metadata: }
    end

    def billing_success_url
      person_billing_url(@person, locale: I18n.locale, checkout_session_id: '{CHECKOUT_SESSION_ID}')
    end

    def billing_cancel_url
      person_billing_url(@person, locale: I18n.locale)
    end

    def payment_processor
      @payment_processor ||= @person.set_payment_processor(:stripe)
    end

    def current_billing_subscription
      @current_billing_subscription ||= BetterTogether::Billing::Subscription.current_for_owner(@person)
    end

    def valid_checkout_session_id?
      params[:checkout_session_id].to_s.match?(/\Acs_[a-zA-Z0-9_]+\z/)
    end

    def sync_checkout_session
      result = BetterTogether::Billing::StripeCheckoutSessionSync.new.call(
        checkout_session_id: params[:checkout_session_id],
        billable_owner: @person,
        beneficiary: @person
      )
      flash.now[sync_flash_key(result)] = sync_flash_message(result)
      result
    rescue Stripe::InvalidRequestError => e
      flash.now[:alert] = t(
        'better_together.billing.checkout_session_invalid',
        default: 'The Stripe checkout session could not be synchronized: %<message>s',
        message: ERB::Util.html_escape(e.message)
      )
      nil
    end

    def sync_flash_key(result)
      result&.synced ? :notice : :alert
    end

    def sync_flash_message(result)
      return t('better_together.billing.checkout_sync_complete', default: 'Stripe checkout was synchronized successfully.') if result&.synced
      if result&.reason.in?(%i[beneficiary_mismatch billable_owner_mismatch ownership_mismatch])
        return t(
          'better_together.billing.checkout_sync_wrong_beneficiary',
          default: 'This Stripe checkout session does not belong to this billing page.'
        )
      end

      t(
        'better_together.billing.checkout_sync_pending',
        default: 'Stripe checkout was received, but no subscription state could be synchronized yet.'
      )
    end

    def current_merchant_account
      @current_merchant_account ||= @person.merchant_accounts.find_by(provider: 'stripe_connect')
    end

    def merchant_onboarding_service
      @merchant_onboarding_service ||= BetterTogether::Billing::MerchantAccounts::StripeConnect::CreateOnboardingLink.new
    end

    def merchant_refresh_service
      @merchant_refresh_service ||= BetterTogether::Billing::MerchantAccounts::StripeConnect::RefreshAccount.new
    end

    def billing_event_replay_service
      @billing_event_replay_service ||= BetterTogether::Billing::ReplayStripeBillingEvent.new
    end

    def merchant_onboarding_result
      merchant_onboarding_service.call(
        owner: @person,
        refresh_url: person_billing_url(@person, locale: I18n.locale),
        return_url: person_billing_url(@person, locale: I18n.locale)
      )
    end

    def billing_alert_events
      billing_events_scope.problematic.newest_first.limit(5)
    end

    def billing_alert_summary
      BetterTogether::Billing::Event.operator_alert_summary(billing_events_scope)
    end

    def last_billing_event
      billing_events_scope.newest_first.first
    end

    def billing_events_scope
      BetterTogether::Billing::Event.for_owner_or_beneficiary(@person).distinct
    end

    # rubocop:disable Style/MultilineBlockChain
    def sponsored_communities
      BetterTogether::Billing::Subscription
        .for_owner(@person)
        .includes(:billing_plan, :pay_subscription)
        .filter_map do |subscription|
          beneficiary = subscription.beneficiary
          next unless beneficiary.is_a?(BetterTogether::Community)

          subscription
        end
        .sort_by { |subscription| subscription.updated_at || Time.at(0) }
        .reverse
    end
    # rubocop:enable Style/MultilineBlockChain

    def replayable_billing_event
      billing_events_scope.dead_lettered.find(params[:event_id])
    end

    def redirect_to_billing_with_notice(message)
      redirect_to person_billing_path(@person, locale: I18n.locale), notice: message, status: :see_other
    end

    def redirect_to_billing_with_alert(message)
      redirect_to person_billing_path(@person, locale: I18n.locale), alert: message, status: :see_other
    end

    def merchant_onboarding_unavailable_message(error)
      t(
        'better_together.billing.merchant_onboarding_unavailable',
        default: 'Merchant onboarding is not available yet: %<message>s',
        message: ERB::Util.html_escape(error.message)
      )
    end

    def merchant_not_connected_message
      t(
        'better_together.billing.merchant_not_connected',
        default: 'No merchant account is connected yet.'
      )
    end

    def merchant_refresh_complete_message
      t(
        'better_together.billing.merchant_refresh_complete',
        default: 'Merchant account status was refreshed successfully.'
      )
    end

    def merchant_refresh_failed_message(error)
      t(
        'better_together.billing.merchant_refresh_failed',
        default: 'Merchant account refresh failed: %<message>s',
        message: ERB::Util.html_escape(error.message)
      )
    end

    def replay_event_flash(replay_result)
      if replay_result.enqueued
        {
          notice: t(
            'better_together.billing.replay_event_enqueued',
            default: 'The dead-lettered billing event was queued for replay.'
          )
        }
      else
        {
          alert: replay_event_failure_message(replay_result.reason)
        }
      end
    end

    def replay_event_failure_message(reason)
      case reason
      when :payload_unavailable
        t(
          'better_together.billing.replay_event_payload_unavailable',
          default: 'This billing event can no longer be replayed because the original payload was redacted.'
        )
      when :unsupported_processor
        t(
          'better_together.billing.replay_event_unsupported',
          default: 'This billing event cannot be replayed from the current billing surface.'
        )
      else
        replay_event_not_found_message
      end
    end

    def replay_event_not_found_message
      t(
        'better_together.billing.replay_event_not_found',
        default: 'That billing event is no longer available for replay.'
      )
    end
  end
end

# frozen_string_literal: true

module BetterTogether
  module Billing
    # Shared billing-page actions for CommunityBillingsController and
    # PersonBillingsController. Every action here treats the billing owner as
    # self-owned only — sponsorship-specific concerns (contributing to a
    # DIFFERENT owner's balance, provisioning a hosted platform) live on
    # CommunityBillingsController alone, not here.
    #
    # Required hooks each including controller must define:
    #   billing_owner            -> @community / @person
    #   set_billing_owner        -> before_action, assigns the ivar
    #   authorize_billing_owner  -> before_action, Pundit authorize
    #   billing_path_helper_prefix -> :community_billing / :person_billing
    #
    # Overridable hooks with single-owner defaults:
    #   load_billing_overview_extras, portal_owner, reconciliation_targets
    module ControllerConcern # rubocop:disable Metrics/ModuleLength
      extend ActiveSupport::Concern

      included do
        before_action :authenticate_user!
        before_action :set_billing_owner
        before_action :authorize_billing_owner
        before_action :authorize_merchant_account_management, only: %i[merchant_onboarding refresh_merchant_account]
        after_action :verify_authorized
      end

      def show
        @checkout_session_pending = valid_checkout_session_id?
        enqueue_checkout_session_sync if @checkout_session_pending
        @billing_plans = available_billing_plans
        @billing_subscription = current_billing_subscription
        @merchant_account = current_merchant_account
        @billing_alert_events = billing_alert_events
        @billing_alert_summary = billing_alert_summary
        @last_billing_event = last_billing_event
        load_billing_overview_extras
      end

      def checkout
        redirect_to checkout_session_for(find_billing_plan).url, allow_other_host: true
      rescue ActiveRecord::RecordNotFound
        redirect_to_billing_with_alert(plan_not_found_message)
      rescue StandardError => e
        redirect_to_billing_with_alert(checkout_unavailable_message(e))
      end

      def portal
        owner = portal_owner
        return redirect_to_billing_with_alert(portal_owner_unavailable_message) unless owner

        current_billing_subscription&.clear_portal_access_failure!
        redirect_to billing_portal_session_for(owner).url, allow_other_host: true
      rescue StandardError => e
        current_billing_subscription&.record_portal_access_failure!(message: e.message)
        redirect_to_billing_with_alert(portal_unavailable_message(e))
      end

      def reconcile
        reconciliation_targets.each do |owner|
          BetterTogether::Billing::ReconcileStripeBillableOwnerBillingJob.perform_later(owner.class.name, owner.id)
        end

        redirect_to_billing_with_notice(reconciliation_enqueued_message)
      end

      def merchant_onboarding
        redirect_to merchant_onboarding_result.url, allow_other_host: true
      rescue BetterTogether::Billing::MerchantAccounts::StripeConnect::CreateOnboardingLink::OnboardingDisabledError => e
        redirect_to_billing_with_alert(e.message)
      rescue StandardError => e
        redirect_to_billing_with_alert(merchant_onboarding_unavailable_message(e))
      end

      def refresh_merchant_account
        merchant_refresh_service.call(merchant_account: current_merchant_account, owner: billing_owner)

        redirect_to_billing_with_notice(merchant_refresh_complete_message)
      rescue StandardError => e
        redirect_to_billing_with_alert(merchant_refresh_failed_message(e))
      end

      def replay_event
        event = replayable_billing_event
        replay_result = billing_event_replay_service.call(billing_event: event, requested_by: current_user)

        redirect_to billing_path, flash: replay_event_flash(replay_result, event), status: :see_other
      rescue ActiveRecord::RecordNotFound
        redirect_to_billing_with_alert(replay_event_not_found_message)
      end

      def accepts_sponsorship
        billing_owner.update!(accepts_sponsorship: sponsorship_opt_in_param)

        redirect_to_billing_with_notice(accepts_sponsorship_updated_message)
      rescue ActiveRecord::RecordInvalid => e
        redirect_to_billing_with_alert(e.record.errors.full_messages.to_sentence)
      end

      private

      def sponsorship_opt_in_param
        ActiveModel::Type::Boolean.new.cast(params[:accepts_sponsorship])
      end

      def accepts_sponsorship_updated_message
        if billing_owner.accepts_sponsorship?
          t(
            'better_together.billing.accepts_sponsorship_enabled',
            default: 'This account can now receive sponsorship contributions.'
          )
        else
          t(
            'better_together.billing.accepts_sponsorship_disabled',
            default: 'This account will no longer receive new sponsorship contributions.'
          )
        end
      end

      # Sponsorships where billing_owner is the beneficiary, awaiting a
      # decision. Used to render an "offers received" panel.
      def received_sponsorship_offers
        BetterTogether::Billing::Sponsorship.where(beneficiary: billing_owner).status_pending.order(created_at: :desc)
      end

      # Active sponsorships where billing_owner is the beneficiary — i.e. who
      # is currently sponsoring this account.
      def received_active_sponsorships
        active_sponsorships_scope.where(beneficiary: billing_owner)
      end

      # Active sponsorships where billing_owner is the sponsor — i.e. who
      # this account is currently sponsoring.
      def given_active_sponsorships
        active_sponsorships_scope.where(sponsor: billing_owner)
      end

      def active_sponsorships_scope
        BetterTogether::Billing::Sponsorship.where(status: %w[accepted active]).order(created_at: :desc)
      end

      def authorize_merchant_account_management
        authorize billing_owner, :manage_merchant_account?
      end

      def available_billing_plans
        BetterTogether::Billing::Plan.active.order(:amount_cents, :name).select do |plan|
          plan.launch_ready_for_hosted_billing? && plan.eligible_for?(billing_owner)
        end
      end

      def checkout_metadata(billing_plan)
        BetterTogether::Billing::OwnershipResolver.build_metadata(billing_plan:)
      end

      def find_billing_plan
        available_billing_plans.find { |plan| plan.identifier == params[:billing_plan_id] } ||
          raise(ActiveRecord::RecordNotFound)
      end

      def checkout_session_for(billing_plan)
        billing_owner.set_payment_processor(:stripe).checkout(**checkout_options(billing_plan))
      end

      def checkout_options(billing_plan)
        metadata = checkout_metadata(billing_plan)

        {
          mode: billing_plan.recurring? ? 'subscription' : 'payment',
          line_items: [{ price: billing_plan.stripe_price_id, quantity: 1 }],
          success_url: billing_success_url,
          cancel_url: billing_cancel_url,
          allow_promotion_codes: true,
          client_reference_id: billing_owner.id,
          metadata:,
          subscription_data: subscription_checkout_data(billing_plan, metadata)
        }
      end

      def subscription_checkout_data(billing_plan, metadata)
        return unless billing_plan.recurring?

        { metadata: }
      end

      def billing_success_url
        billing_url(checkout_session_id: '{CHECKOUT_SESSION_ID}')
      end

      def billing_cancel_url
        billing_url
      end

      def billing_path(**)
        send(:"#{billing_path_helper_prefix}_path", billing_owner, locale: I18n.locale, **)
      end

      def billing_url(**)
        send(:"#{billing_path_helper_prefix}_url", billing_owner, locale: I18n.locale, **)
      end

      def valid_checkout_session_id?
        params[:checkout_session_id].to_s.match?(/\Acs_[a-zA-Z0-9_]+\z/)
      end

      def enqueue_checkout_session_sync
        BetterTogether::Billing::SyncCheckoutSessionJob.perform_later(
          params[:checkout_session_id], billing_owner.class.name, billing_owner.id
        )
      end

      def current_billing_subscription
        @current_billing_subscription ||= BetterTogether::Billing::Subscription.current_for_owner(billing_owner)
      end

      # Overridable — default is "nothing extra to load." Community adds
      # sponsorship-contribution plans/received-contributions and processes
      # any just-completed contribution checkout; Person adds its
      # sponsored-communities list.
      def load_billing_overview_extras; end

      def billing_portal_session_for(owner)
        owner.set_payment_processor(:stripe).billing_portal(return_url: billing_url)
      end

      def current_merchant_account
        @current_merchant_account ||= billing_owner.merchant_accounts.find_by(provider: 'stripe_connect')
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
        merchant_onboarding_service.call(owner: billing_owner, refresh_url: billing_url, return_url: billing_url)
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
        BetterTogether::Billing::Event.for_owner_or_beneficiary(billing_owner).distinct
      end

      # Overridable — default is "reconcile myself only." Community overrides
      # to also reconcile the historical billable_owner of its current
      # subscription (relevant for data predating the sponsorship redesign).
      def reconciliation_targets
        [billing_owner]
      end

      def replayable_billing_event
        billing_events_scope.dead_lettered.find(params[:event_id])
      end

      def redirect_to_billing_with_notice(message)
        redirect_to billing_path, notice: message, status: :see_other
      end

      def redirect_to_billing_with_alert(message)
        redirect_to billing_path, alert: message, status: :see_other
      end

      # Overridable — default is "always billing_owner." Community overrides
      # to a legacy-sponsor-aware resolution (portal_billable_owner).
      def portal_owner
        billing_owner
      end

      def portal_owner_unavailable_message
        t(
          'better_together.billing.portal_owner_unavailable',
          default: 'This subscription is billed to another owner.'
        )
      end

      def plan_not_found_message
        t('better_together.billing.plan_not_found', default: 'That billing plan is not available.')
      end

      def reconciliation_enqueued_message
        t(
          'better_together.billing.reconciliation_enqueued',
          default: 'A Stripe reconciliation job was queued for this billing account.'
        )
      end

      def checkout_unavailable_message(error)
        t(
          'better_together.billing.checkout_unavailable',
          default: 'Checkout is not available right now: %<message>s',
          message: ERB::Util.html_escape(error.message)
        )
      end

      def portal_unavailable_message(error)
        t(
          'better_together.billing.portal_unavailable',
          default: 'The billing portal is not available yet: %<message>s',
          message: ERB::Util.html_escape(error.message)
        )
      end

      def merchant_onboarding_unavailable_message(error)
        t(
          'better_together.billing.merchant_onboarding_unavailable',
          default: 'Merchant onboarding is not available yet: %<message>s',
          message: ERB::Util.html_escape(error.message)
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

      def replay_event_flash(replay_result, billing_event)
        if replay_result.enqueued
          {
            notice: t(
              'better_together.billing.replay_event_enqueued',
              default: 'Billing event %<event_type>s queued for replay.',
              event_type: billing_event.event_type
            )
          }
        else
          { alert: replay_event_failure_message(replay_result.reason) }
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
end

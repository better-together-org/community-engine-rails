# frozen_string_literal: true

module BetterTogether
  # Community steward billing entry points for Stripe checkout and portal access.
  class CommunityBillingsController < ApplicationController # rubocop:todo Metrics/ClassLength
    include NewPlatformSetupKickoff

    before_action :authenticate_user!
    before_action :set_community
    before_action :authorize_community
    before_action :authorize_merchant_account_management, only: %i[merchant_onboarding refresh_merchant_account]
    after_action :verify_authorized

    def show
      @checkout_sync_result = sync_checkout_session if valid_checkout_session_id?
      process_sponsorship_contribution(@checkout_sync_result) if @checkout_sync_result&.one_time_payment.present?
      load_billing_overview
    end

    def checkout
      redirect_to checkout_session_for(find_billing_plan).url, allow_other_host: true
    rescue ActiveRecord::RecordNotFound
      redirect_to community_billing_path(@community, locale: I18n.locale),
                  alert: t('better_together.billing.plan_not_found', default: 'That billing plan is not available.'),
                  status: :see_other
    end

    # This community, acting as sponsor, contributes to a DIFFERENT
    # community's Stripe Customer Balance — never touches the beneficiary's
    # own subscription/ownership. Replaces the old "takeover" mechanism.
    def contribute
      beneficiary = find_sponsorship_beneficiary
      return redirect_to_billing_with_alert(sponsorship_consent_required_message) unless beneficiary_accepts_sponsorship?(beneficiary)

      billing_plan = find_sponsorship_contribution_plan
      redirect_to sponsorship_checkout_session_for(beneficiary, billing_plan).url, allow_other_host: true
    rescue ActiveRecord::RecordNotFound
      redirect_to_billing_with_alert(sponsorship_target_invalid_message)
    end

    def portal
      owner = portal_billable_owner
      return redirect_to_billing_with_alert(portal_owner_unavailable_message) unless owner

      current_billing_subscription&.clear_portal_access_failure!
      redirect_to billing_portal_session_for(owner).url, allow_other_host: true
    rescue StandardError => e
      current_billing_subscription&.record_portal_access_failure!(message: e.message)
      redirect_to_portal_unavailable(e)
    end

    def reconcile
      reconciliation_targets.each do |owner|
        BetterTogether::Billing::ReconcileStripeBillableOwnerBillingJob.perform_later(
          owner.class.name,
          owner.id
        )
      end

      redirect_to community_billing_path(@community, locale: I18n.locale),
                  notice: t(
                    'better_together.billing.reconciliation_enqueued',
                    default: 'A Stripe reconciliation job was queued for this community.'
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
      merchant_refresh_service.call(merchant_account: current_merchant_account, owner: @community)

      redirect_to_billing_with_notice(merchant_refresh_complete_message)
    rescue StandardError => e
      redirect_to_billing_with_alert(merchant_refresh_failed_message(e))
    end

    def replay_event
      event = replayable_billing_event
      replay_result = billing_event_replay_service.call(
        billing_event: event,
        requested_by: current_user
      )

      redirect_to community_billing_path(@community, locale: I18n.locale),
                  flash: replay_event_flash(replay_result, event),
                  status: :see_other
    rescue ActiveRecord::RecordNotFound
      redirect_to_billing_with_alert(replay_event_not_found_message)
    end

    # Entitlement pre-check + kickoff redirect into the new_platform_setup wizard
    # (docs/plans/richer_platform_setup_wizard_implementation_plan.md, "Phase 5:
    # Billing entry-point wiring"). Does not authorize via PlatformPolicy#create?
    # like the wizard's own staff-facing entry point (NewPlatformSetupController#
    # start) — a paying community steward legitimately won't hold platform-admin
    # permissions. authorize_community's existing CommunityPolicy#update? check
    # (before_action, all actions) plus the entitlement check below are the gate
    # for this path; verify_authorized is satisfied by that before_action.
    def provision_platform
      @hosted_entitlement = hosted_entitlement_resolver.call(community: @community)
      return redirect_to_billing_with_alert(provision_requires_plan_message) unless @hosted_entitlement.active?

      draft = build_new_platform_setup_draft(provisioning_community: @community)
      provision_new_platform_setup_draft(draft)
      redirect_to new_platform_setup_step_welcome_path(platform_id: draft.to_param)
    rescue ActiveRecord::RecordInvalid => e
      redirect_to_billing_with_alert(e.record.errors.full_messages.to_sentence)
    end

    private

    def set_community
      @community = BetterTogether::Community.friendly.find(params[:community_id])
    end

    def authorize_community
      authorize @community, :update?
    end

    def authorize_merchant_account_management
      authorize @community, :manage_merchant_account?
    end

    def available_billing_plans
      BetterTogether::Billing::Plan.active.order(:amount_cents, :name).select do |plan|
        plan.launch_ready_for_hosted_billing? && plan.eligible_for?(@community)
      end
    end

    # Subscription checkout on this page is always self-pay — a community can
    # only subscribe as itself. Funding a DIFFERENT community's balance is a
    # separate action (#contribute) with its own metadata shape; the two are
    # not layered onto the same checkout entry point anymore.
    def checkout_metadata(billing_plan)
      BetterTogether::Billing::OwnershipResolver.build_metadata(billing_plan:)
    end

    def find_billing_plan
      available_billing_plans.find { |plan| plan.identifier == params[:billing_plan_id] } || raise(ActiveRecord::RecordNotFound)
    end

    def checkout_session_for(billing_plan)
      @community.set_payment_processor(:stripe).checkout(**checkout_options(billing_plan))
    end

    def checkout_options(billing_plan)
      metadata = checkout_metadata(billing_plan)

      {
        mode: billing_plan.recurring? ? 'subscription' : 'payment',
        line_items: [{ price: billing_plan.stripe_price_id, quantity: 1 }],
        success_url: billing_success_url,
        cancel_url: billing_cancel_url,
        allow_promotion_codes: true,
        client_reference_id: @community.id,
        metadata:,
        subscription_data: subscription_checkout_data(billing_plan, metadata)
      }
    end

    def subscription_checkout_data(billing_plan, metadata)
      return unless billing_plan.recurring?

      { metadata: }
    end

    def find_sponsorship_beneficiary
      BetterTogether::Community.friendly.find(params[:beneficiary_community_id])
    end

    # Fail closed BEFORE any Stripe redirect — the model-level validation on
    # Sponsorship#create only fires once find_or_create_active_sponsorship
    # runs, which happens AFTER the sponsor's payment already succeeded. This
    # check prevents "money moved, tracking lost" for an opted-out beneficiary.
    def beneficiary_accepts_sponsorship?(beneficiary)
      return true unless BetterTogether::Billing::Sponsorship.consent_enforced?

      beneficiary.respond_to?(:accepts_sponsorship?) && beneficiary.accepts_sponsorship?
    end

    def find_sponsorship_contribution_plan
      available_sponsorship_contribution_plans.find { |plan| plan.identifier == params[:billing_plan_id] } ||
        raise(ActiveRecord::RecordNotFound)
    end

    def sponsorship_checkout_session_for(beneficiary, billing_plan)
      @community.set_payment_processor(:stripe).checkout(**sponsorship_checkout_options(beneficiary, billing_plan))
    end

    def sponsorship_checkout_options(beneficiary, billing_plan)
      {
        mode: 'payment',
        line_items: [{ price: billing_plan.stripe_price_id, quantity: 1 }],
        success_url: billing_success_url,
        cancel_url: billing_cancel_url,
        client_reference_id: @community.id,
        metadata: sponsorship_checkout_metadata(beneficiary, billing_plan)
      }
    end

    def sponsorship_checkout_metadata(beneficiary, billing_plan)
      BetterTogether::Billing::OwnershipResolver.build_metadata(billing_plan:).merge(
        bt_sponsorship_beneficiary_type: beneficiary.class.name,
        bt_sponsorship_beneficiary_id: beneficiary.id
      )
    end

    # Best-effort immediate UI feedback on browser return — the webhook leg
    # (StripeEventProcessor#process_sponsorship_contribution) is the
    # authoritative trigger and fires even if the payer never lands back
    # here. Both call the same shared, idempotent service, so whichever
    # leg runs first actually credits the balance and the other safely
    # no-ops (result.credit_result.already_credited).
    def process_sponsorship_contribution(result)
      service_result = BetterTogether::Billing::ProcessSponsorshipContribution.new.call(
        one_time_payment: result.one_time_payment, checkout_session: result.checkout_session
      )
      flash_sponsorship_contribution_result(service_result)
    rescue ActiveRecord::RecordInvalid, Stripe::StripeError => e
      flash.now[:alert] = sponsorship_contribution_failed_message(e)
    end

    def flash_sponsorship_contribution_result(service_result)
      return if service_result.blank? || service_result.credit_result.already_credited

      flash.now[:notice] = sponsorship_contribution_complete_message(service_result.beneficiary)
    end

    def sponsorship_target_invalid_message
      t(
        'better_together.billing.sponsorship_target_invalid',
        default: 'That community or contribution amount is not available.'
      )
    end

    def sponsorship_consent_required_message
      t(
        'better_together.billing.sponsorship_consent_required',
        default: 'This community has not opted in to receive sponsorship contributions.'
      )
    end

    def sponsorship_contribution_complete_message(beneficiary)
      t(
        'better_together.billing.sponsorship_contribution_complete',
        default: 'Your contribution to %<beneficiary>s was recorded.',
        beneficiary: beneficiary.name
      )
    end

    def sponsorship_contribution_failed_message(error)
      t(
        'better_together.billing.sponsorship_contribution_failed',
        default: 'Your payment succeeded, but recording the contribution failed: %<message>s',
        message: ERB::Util.html_escape(error.message)
      )
    end

    def billing_success_url
      community_billing_url(@community, locale: I18n.locale, checkout_session_id: '{CHECKOUT_SESSION_ID}')
    end

    def billing_cancel_url
      community_billing_url(@community, locale: I18n.locale)
    end

    def valid_checkout_session_id?
      params[:checkout_session_id].to_s.match?(/\Acs_[a-zA-Z0-9_]+\z/)
    end

    def sync_checkout_session
      result = BetterTogether::Billing::StripeCheckoutSessionSync.new.call(
        checkout_session_id: params[:checkout_session_id],
        beneficiary: @community
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
      if result&.reason == :beneficiary_mismatch
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

    def current_billing_subscription
      @current_billing_subscription ||= BetterTogether::Billing::Subscription.current_for_owner(@community)
    end

    # rubocop:disable Metrics/AbcSize
    def load_billing_overview
      @billing_plans = available_billing_plans
      @billing_subscription = current_billing_subscription
      @hosted_entitlement = hosted_entitlement_resolver.call(
        community: @community,
        billing_subscription: @billing_subscription
      )
      @current_billing_plan = @billing_subscription&.billing_plan
      @merchant_account = current_merchant_account
      @billing_alert_events = billing_alert_events
      @billing_alert_summary = billing_alert_summary
      @last_billing_event = last_billing_event
      @sponsorship_contribution_plans = available_sponsorship_contribution_plans
      @received_monetary_contributions = received_monetary_contributions
    end
    # rubocop:enable Metrics/AbcSize

    def billing_portal_session_for(billable_owner)
      billable_owner.set_payment_processor(:stripe).billing_portal(
        return_url: community_billing_url(@community, locale: I18n.locale)
      )
    end

    def redirect_to_portal_unavailable(error)
      redirect_to community_billing_path(@community, locale: I18n.locale),
                  alert: t(
                    'better_together.billing.portal_unavailable',
                    default: 'The billing portal is not available yet: %<message>s',
                    message: ERB::Util.html_escape(error.message)
                  ),
                  status: :see_other
    end

    def current_merchant_account
      @current_merchant_account ||= @community.merchant_accounts.find_by(provider: 'stripe_connect')
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

    def hosted_entitlement_resolver
      @hosted_entitlement_resolver ||= BetterTogether::Billing::HostedEntitlementResolver.new
    end

    def merchant_onboarding_result
      merchant_onboarding_service.call(
        owner: @community,
        refresh_url: community_billing_url(@community, locale: I18n.locale),
        return_url: community_billing_url(@community, locale: I18n.locale)
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
      BetterTogether::Billing::Event.for_owner_or_beneficiary(@community).distinct
    end

    def reconciliation_targets
      [current_billing_subscription&.billable_owner, @community].compact.uniq.presence || [@community]
    end

    def replayable_billing_event
      billing_events_scope.dead_lettered.find(params[:event_id])
    end

    def redirect_to_billing_with_notice(message)
      redirect_to community_billing_path(@community, locale: I18n.locale), notice: message, status: :see_other
    end

    def redirect_to_billing_with_alert(message)
      redirect_to community_billing_path(@community, locale: I18n.locale), alert: message, status: :see_other
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

    def available_sponsorship_contribution_plans
      BetterTogether::Billing::Plan.active.order(:amount_cents).select(&:sponsorship_contribution?)
    end

    def received_monetary_contributions
      BetterTogether::Billing::MonetaryContribution.joins(:sponsorship)
                                                   .merge(BetterTogether::Billing::Sponsorship.for_beneficiary(@community))
    end

    # rubocop:disable Metrics/CyclomaticComplexity
    def portal_billable_owner
      owner = current_billing_subscription&.billable_owner
      return @community if owner.blank? || owner == @community
      return owner if owner.is_a?(BetterTogether::Person) && owner == current_user.person
      return owner if owner.is_a?(BetterTogether::Community) && policy(owner).update?

      nil
    end
    # rubocop:enable Metrics/CyclomaticComplexity

    def portal_owner_unavailable_message
      t(
        'better_together.billing.portal_owner_unavailable',
        default: 'This community subscription is billed to another owner.'
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

    def provision_requires_plan_message
      t('better_together.billing.provision_requires_active_plan',
        default: 'An active hosted plan is required to provision a platform. Subscribe to a hosted plan first.')
    end
  end
end

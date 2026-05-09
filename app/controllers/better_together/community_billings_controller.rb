# frozen_string_literal: true

module BetterTogether
  # Community-admin billing entry points for Stripe checkout and portal access.
  class CommunityBillingsController < ApplicationController # rubocop:todo Metrics/ClassLength
    before_action :authenticate_user!
    before_action :set_community
    before_action :authorize_community
    before_action :authorize_merchant_account_management, only: %i[merchant_onboarding refresh_merchant_account]

    def show
      @checkout_sync_result = sync_checkout_session if params[:checkout_session_id].present?
      load_billing_overview
    end

    def checkout
      redirect_to checkout_session_for(find_billing_plan).url, allow_other_host: true
    rescue ActiveRecord::RecordNotFound
      redirect_to community_billing_path(@community, locale: I18n.locale),
                  alert: t('better_together.billing.plan_not_found', default: 'That billing plan is not available.'),
                  status: :see_other
    end

    def portal
      billable_owner = portal_billable_owner
      return redirect_to_portal_sponsor_guidance unless billable_owner

      current_billing_subscription&.clear_portal_access_failure!
      redirect_to billing_portal_session_for(billable_owner).url, allow_other_host: true
    rescue StandardError => e
      current_billing_subscription&.record_portal_access_failure!(message: e.message)
      redirect_to_portal_unavailable(e)
    end

    def reconcile
      billable_owner = current_billing_subscription&.billable_owner || @community
      BetterTogether::Billing::ReconcileStripeBillableOwnerBillingJob.perform_later(
        billable_owner.class.name,
        billable_owner.id
      )

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
      merchant_refresh_service.call(merchant_account: current_merchant_account!)

      redirect_to_billing_with_notice(merchant_refresh_complete_message)
    rescue ActiveRecord::RecordNotFound
      redirect_to_billing_with_alert(merchant_not_connected_message)
    rescue StandardError => e
      redirect_to_billing_with_alert(merchant_refresh_failed_message(e))
    end

    def replay_event
      replay_result = billing_event_replay_service.call(
        billing_event: replayable_billing_event,
        requested_by: current_user
      )

      redirect_to community_billing_path(@community, locale: I18n.locale),
                  flash: replay_event_flash(replay_result),
                  status: :see_other
    rescue ActiveRecord::RecordNotFound
      redirect_to_billing_with_alert(replay_event_not_found_message)
    end

    def provision_platform
      @hosted_entitlement = hosted_entitlement_resolver.call(community: @community)
    end

    def create_platform_provision
      @hosted_entitlement = hosted_entitlement_resolver.call(community: @community)
      return redirect_to_billing_with_alert(provision_requires_plan_message) unless @hosted_entitlement.active?

      handle_provision_result(::BetterTogether::TenantPlatformProvisioningService.call(**platform_provision_params_hash))
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

    def checkout_metadata(billing_plan, billable_owner:)
      BetterTogether::Billing::OwnershipResolver.build_metadata(
        billable_owner:,
        beneficiary: @community
      ).merge(
        bt_billing_plan_id: billing_plan.id,
        bt_billing_plan_identifier: billing_plan.identifier
      )
    end

    def find_billing_plan
      available_billing_plans.find { |plan| plan.id == params[:billing_plan_id] } || raise(ActiveRecord::RecordNotFound)
    end

    def checkout_session_for(billing_plan)
      billable_owner = checkout_billable_owner_for(billing_plan)
      payment_processor(billable_owner).checkout(**checkout_options(billing_plan, billable_owner))
    end

    def checkout_options(billing_plan, billable_owner)
      metadata = checkout_metadata(billing_plan, billable_owner:)

      {
        mode: billing_plan.recurring? ? 'subscription' : 'payment',
        line_items: [{ price: billing_plan.stripe_price_id, quantity: 1 }],
        success_url: billing_success_url,
        cancel_url: billing_cancel_url,
        allow_promotion_codes: true,
        client_reference_id: billable_owner.id,
        metadata:,
        subscription_data: subscription_checkout_data(billing_plan, metadata)
      }
    end

    def subscription_checkout_data(billing_plan, metadata)
      return unless billing_plan.recurring?

      { metadata: }
    end

    def billing_success_url
      community_billing_url(@community, locale: I18n.locale, checkout_session_id: '{CHECKOUT_SESSION_ID}')
    end

    def billing_cancel_url
      community_billing_url(@community, locale: I18n.locale)
    end

    def payment_processor(billable_owner = @community)
      billable_owner.set_payment_processor(:stripe)
    end

    def sync_checkout_session
      result = BetterTogether::Billing::StripeCheckoutSessionSync.new.call(
        checkout_session_id: params[:checkout_session_id]
      )
      flash.now[sync_flash_key(result)] = sync_flash_message(result)
      result
    rescue Stripe::InvalidRequestError => e
      flash.now[:alert] = t(
        'better_together.billing.checkout_session_invalid',
        default: 'The Stripe checkout session could not be synchronized: %<message>s',
        message: e.message
      )
      nil
    end

    def sync_flash_key(result)
      result&.synced ? :notice : :alert
    end

    def sync_flash_message(result)
      return t('better_together.billing.checkout_sync_complete', default: 'Stripe checkout was synchronized successfully.') if result&.synced

      t(
        'better_together.billing.checkout_sync_pending',
        default: 'Stripe checkout was received, but no subscription state could be synchronized yet.'
      )
    end

    def current_billing_subscription
      @community.billing_subscriptions.order(updated_at: :desc).first
    end

    def load_billing_overview
      @billing_plans = available_billing_plans
      @billing_subscription = current_billing_subscription
      @hosted_entitlement = hosted_entitlement_resolver.call(
        community: @community,
        billing_subscription: @billing_subscription
      )
      @current_billing_plan = @billing_subscription&.billing_plan
      @sponsoring_person = sponsoring_person
      @sponsoring_communities = sponsoring_communities
      @merchant_account = current_merchant_account
      @billing_alert_events = billing_alert_events
      @billing_alert_summary = billing_alert_summary
      @last_billing_event = last_billing_event
    end

    def sponsoring_person
      current_user&.person
    end

    def checkout_billable_owner_for(billing_plan)
      return @community unless sponsor_checkout_requested?

      sponsored_owner = requested_sponsor_owner
      return @community unless sponsored_owner.present? && billing_plan.eligible_for?(sponsored_owner)

      sponsored_owner
    end

    def sponsor_checkout_requested?
      params[:checkout_as].to_s.in?(%w[person community])
    end

    def portal_billable_owner
      billable_owner = current_billing_subscription&.billable_owner
      return @community if billable_owner.blank? || billable_owner == @community
      return billable_owner if billable_owner == sponsoring_person
      return billable_owner if billable_owner.is_a?(BetterTogether::Community) && sponsoring_communities.include?(billable_owner)

      nil
    end

    def sponsoring_communities
      @sponsoring_communities ||= BetterTogether::Community.all.select do |community|
        community != @community && policy(community).update?
      end.sort_by(&:to_s)
    end

    def requested_sponsor_owner
      case params[:checkout_as].to_s
      when 'person'
        sponsoring_person
      when 'community'
        sponsoring_communities.find { |community| community.id == params[:billable_owner_community_id] }
      end
    end

    def billing_portal_session_for(billable_owner)
      billable_owner.set_payment_processor(:stripe).billing_portal(
        return_url: community_billing_url(@community, locale: I18n.locale)
      )
    end

    def redirect_to_portal_sponsor_guidance
      redirect_to community_billing_path(@community, locale: I18n.locale),
                  alert: t(
                    'better_together.billing.portal_requires_sponsor',
                    default: 'This community subscription is billed to another owner. ' \
                             'Ask the current sponsor to open the billing portal, or start a ' \
                             'new checkout below to take over billing for this community.'
                  ),
                  status: :see_other
    end

    def redirect_to_portal_unavailable(error)
      redirect_to community_billing_path(@community, locale: I18n.locale),
                  alert: t(
                    'better_together.billing.portal_unavailable',
                    default: 'The billing portal is not available yet: %<message>s',
                    message: error.message
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

    def current_merchant_account!
      current_merchant_account || raise(ActiveRecord::RecordNotFound)
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
      BetterTogether::Billing::Event.where(
        '(billable_owner_type = :owner_type AND billable_owner_id = :owner_id) OR ' \
        '(beneficiary_type = :beneficiary_type AND beneficiary_id = :beneficiary_id)',
        owner_type: @community.class.name,
        owner_id: @community.id,
        beneficiary_type: @community.class.name,
        beneficiary_id: @community.id
      ).distinct
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
        message: error.message
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
        message: error.message
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

    def handle_provision_result(result)
      if result.success?
        redirect_to community_billing_path(@community, locale: I18n.locale),
                    notice: t('better_together.billing.platform_provisioned',
                              default: 'Platform provisioned at %<host_url>s.',
                              host_url: result.platform.host_url),
                    status: :see_other
      else
        flash.now[:alert] = result.errors.to_sentence
        render :provision_platform, status: :unprocessable_content
      end
    end

    def provision_requires_plan_message
      t('better_together.billing.provision_requires_active_plan',
        default: 'An active hosted plan is required to provision a platform. Subscribe to a hosted plan first.')
    end

    def platform_provision_params_hash
      {
        name: platform_provision_form_params[:name],
        host_url: platform_provision_form_params[:host_url],
        time_zone: platform_provision_form_params[:time_zone].presence || 'UTC'
      }
    end

    def platform_provision_form_params
      params.require(:platform_provision).permit(:name, :host_url, :time_zone)
    end
  end
end

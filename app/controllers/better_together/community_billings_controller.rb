# frozen_string_literal: true

module BetterTogether
  # Community-admin billing entry points for Stripe checkout and portal access.
  class CommunityBillingsController < ApplicationController # rubocop:todo Metrics/ClassLength
    before_action :authenticate_user!
    before_action :set_community
    before_action :authorize_community

    def show
      @checkout_sync_result = sync_checkout_session if params[:checkout_session_id].present?
      @billing_plans = available_billing_plans
      @billing_subscription = current_billing_subscription
      @current_billing_plan = @billing_subscription&.billing_plan
      @sponsoring_person = sponsoring_person
      @sponsoring_communities = sponsoring_communities
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

      redirect_to billing_portal_session_for(billable_owner).url, allow_other_host: true
    rescue StandardError => e
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

    private

    def set_community
      @community = BetterTogether::Community.friendly.find(params[:community_id])
    end

    def authorize_community
      authorize @community, :update?
    end

    def available_billing_plans
      BetterTogether::Billing::Plan.active.order(:amount_cents, :name).select { |plan| plan.eligible_for?(@community) }
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
  end
end

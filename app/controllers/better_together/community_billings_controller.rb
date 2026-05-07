# frozen_string_literal: true

module BetterTogether
  # Community-admin billing entry points for Stripe checkout and portal access.
  class CommunityBillingsController < ApplicationController # rubocop:todo Metrics/ClassLength
    before_action :authenticate_user!
    before_action :set_community
    before_action :authorize_community

    def show
      @checkout_sync_result = sync_checkout_session if params[:checkout_session_id].present?
      @billing_plans = BetterTogether::Billing::Plan.active.order(:amount_cents, :name)
      @billing_subscription = @community.billing_subscriptions.order(updated_at: :desc).first
    end

    def checkout
      redirect_to checkout_session_for(find_billing_plan).url, allow_other_host: true
    rescue ActiveRecord::RecordNotFound
      redirect_to community_billing_path(@community, locale: I18n.locale),
                  alert: t('better_together.billing.plan_not_found', default: 'That billing plan is not available.'),
                  status: :see_other
    end

    def portal
      portal_session = @community.set_payment_processor(:stripe).billing_portal(
        return_url: community_billing_url(@community, locale: I18n.locale)
      )

      redirect_to portal_session.url, allow_other_host: true
    rescue StandardError => e
      redirect_to community_billing_path(@community, locale: I18n.locale),
                  alert: t(
                    'better_together.billing.portal_unavailable',
                    default: 'The billing portal is not available yet: %<message>s',
                    message: e.message
                  ),
                  status: :see_other
    end

    def reconcile
      BetterTogether::Billing::ReconcileStripeCommunityBillingJob.perform_later(@community.id)

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

    def checkout_metadata(billing_plan)
      {
        bt_community_id: @community.id,
        bt_billing_plan_id: billing_plan.id,
        bt_billing_plan_identifier: billing_plan.identifier
      }
    end

    def find_billing_plan
      BetterTogether::Billing::Plan.active.find(params[:billing_plan_id])
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
        client_reference_id: @community.id,
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

    def payment_processor
      @payment_processor ||= @community.set_payment_processor(:stripe)
    end

    def sync_checkout_session
      result = BetterTogether::Billing::StripeCheckoutSessionSync.new.call(
        checkout_session_id: params[:checkout_session_id],
        community: @community
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
  end
end

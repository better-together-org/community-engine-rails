# frozen_string_literal: true

module BetterTogether
  # Community steward billing entry points for Stripe checkout and portal
  # access. Shared billing-page actions (show/checkout/portal/reconcile/
  # merchant onboarding/replay) live in Billing::ControllerConcern; this
  # class holds only what's genuinely community-specific: sponsoring a
  # DIFFERENT community's balance, and hosted-platform provisioning.
  class CommunityBillingsController < ApplicationController # rubocop:todo Metrics/ClassLength
    include BetterTogether::Billing::ControllerConcern
    include NewPlatformSetupKickoff

    # This community, acting as sponsor, contributes to a DIFFERENT
    # community's Stripe Customer Balance — never touches the beneficiary's
    # own subscription/ownership. Replaces the old "takeover" mechanism.
    def contribute
      beneficiary = find_sponsorship_beneficiary
      billing_plan = find_sponsorship_contribution_plan
      redirect_to sponsorship_checkout_session_for(beneficiary, billing_plan).url, allow_other_host: true
    rescue ActiveRecord::RecordNotFound
      redirect_to_billing_with_alert(sponsorship_target_invalid_message)
    end

    # Entitlement pre-check + kickoff redirect into the new_platform_setup wizard
    # (docs/plans/richer_platform_setup_wizard_implementation_plan.md, "Phase 5:
    # Billing entry-point wiring"). Does not authorize via PlatformPolicy#create?
    # like the wizard's own staff-facing entry point (NewPlatformSetupController#
    # start) — a paying community steward legitimately won't hold platform-admin
    # permissions. authorize_billing_owner's existing CommunityPolicy#update?
    # check (before_action, all actions) plus the entitlement check below are
    # the gate for this path; verify_authorized is satisfied by that before_action.
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

    def billing_owner
      @community
    end

    def set_billing_owner
      @community = BetterTogether::Community.friendly.find(params[:community_id])
    end

    def authorize_billing_owner
      authorize @community, :update?
    end

    def billing_path_helper_prefix
      :community_billing
    end

    def load_billing_overview_extras
      @hosted_entitlement = hosted_entitlement_resolver.call(community: @community, billing_subscription: @billing_subscription)
      @sponsorship_contribution_plans = available_sponsorship_contribution_plans
      @received_monetary_contributions = received_monetary_contributions
      process_sponsorship_contribution(@checkout_sync_result) if @checkout_sync_result&.one_time_payment.present?
    end

    def find_sponsorship_beneficiary
      BetterTogether::Community.friendly.find(params[:beneficiary_community_id])
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

    # Guarded by a MonetaryContribution existence check so revisiting the
    # same checkout_session_id (e.g. a page refresh) never credits the
    # beneficiary's Stripe balance twice for one payment.
    def process_sponsorship_contribution(result)
      one_time_payment = result.one_time_payment
      return if BetterTogether::Billing::MonetaryContribution.exists?(one_time_payment:)

      beneficiary = resolved_sponsorship_beneficiary(result.checkout_session)
      return if beneficiary.blank?

      credit_sponsorship_contribution(one_time_payment:, beneficiary:)
      flash.now[:notice] = sponsorship_contribution_complete_message(beneficiary)
    rescue ActiveRecord::RecordInvalid, Stripe::StripeError => e
      flash.now[:alert] = sponsorship_contribution_failed_message(e)
    end

    def credit_sponsorship_contribution(one_time_payment:, beneficiary:)
      sponsorship = find_or_create_active_sponsorship(sponsor: one_time_payment.owner, beneficiary:)
      BetterTogether::Billing::CreditBeneficiaryBalance.new.call(
        sponsorship:,
        amount_cents: one_time_payment.amount_cents,
        currency: one_time_payment.currency,
        one_time_payment:
      )
    end

    def resolved_sponsorship_beneficiary(checkout_session)
      metadata = checkout_session.metadata.to_h
      BetterTogether::Billing::OwnershipResolver.resolve_record(
        metadata['bt_sponsorship_beneficiary_type'],
        metadata['bt_sponsorship_beneficiary_id']
      )
    end

    def find_or_create_active_sponsorship(sponsor:, beneficiary:)
      BetterTogether::Billing::Sponsorship.status_active
                                          .for_sponsor(sponsor)
                                          .for_beneficiary(beneficiary)
                                          .first ||
        BetterTogether::Billing::Sponsorship.create!(sponsor:, beneficiary:, status: 'active', accepted_at: Time.current)
    end

    def sponsorship_target_invalid_message
      t(
        'better_together.billing.sponsorship_target_invalid',
        default: 'That community or contribution amount is not available.'
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

    def available_sponsorship_contribution_plans
      BetterTogether::Billing::Plan.active.order(:amount_cents).select(&:sponsorship_contribution?)
    end

    def received_monetary_contributions
      BetterTogether::Billing::MonetaryContribution.joins(:sponsorship)
                                                   .merge(BetterTogether::Billing::Sponsorship.for_beneficiary(@community))
    end

    # Overrides ControllerConcern's default (always billing_owner) — a
    # community's subscription may still be owned by a different party for
    # data predating the sponsorship redesign (grandfathered, not migrated
    # automatically — see lib/tasks/better_together/billing_sponsorships.rake).
    # rubocop:disable Metrics/CyclomaticComplexity
    def portal_owner
      owner = current_billing_subscription&.billable_owner
      return @community if owner.blank? || owner == @community
      return owner if owner.is_a?(BetterTogether::Person) && owner == current_user.person
      return owner if owner.is_a?(BetterTogether::Community) && policy(owner).update?

      nil
    end
    # rubocop:enable Metrics/CyclomaticComplexity

    # Overrides ControllerConcern's default (just billing_owner) for the same
    # legacy-data reason as portal_owner above.
    def reconciliation_targets
      [current_billing_subscription&.billable_owner, @community].compact.uniq.presence || [@community]
    end

    def hosted_entitlement_resolver
      @hosted_entitlement_resolver ||= BetterTogether::Billing::HostedEntitlementResolver.new
    end

    def provision_requires_plan_message
      t('better_together.billing.provision_requires_active_plan',
        default: 'An active hosted plan is required to provision a platform. Subscribe to a hosted plan first.')
    end
  end
end

# frozen_string_literal: true

module BetterTogether
  # Person-owned billing entry points for Stripe checkout and portal access.
  # Shared billing-page actions live in Billing::ControllerConcern; this
  # class holds only what's genuinely person-specific: the read-only list of
  # communities this person currently sponsors.
  class PersonBillingsController < ApplicationController
    include BetterTogether::Billing::ControllerConcern

    private

    def billing_owner
      @person
    end

    def set_billing_owner
      @person = BetterTogether::Person.friendly.find(params[:person_id])
    end

    def authorize_billing_owner
      authorize @person, :update?
    end

    def billing_path_helper_prefix
      :person_billing
    end

    def load_billing_overview_extras
      @sponsored_communities = sponsored_communities
    end

    # Communities this person is currently sponsoring (contributing to their
    # Stripe Customer Balance) — a Sponsorship relationship, not a subscription
    # this person owns. See Billing::Sponsorship/CreditBeneficiaryBalance.
    def sponsored_communities
      BetterTogether::Billing::Sponsorship.status_active
                                          .for_sponsor(@person)
                                          .where(beneficiary_type: 'BetterTogether::Community')
                                          .includes(:beneficiary, :monetary_contributions)
                                          .order(created_at: :desc)
    end
  end
end

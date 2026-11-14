# frozen_string_literal: true

module BetterTogether
  module Billing
    # The public catalog: the plans a steward has listed, for anyone to read, each with a button to buy it.
    # Reading needs no sign-in (buying does, at checkout). Billing off for the platform is a 404, as everywhere in billing.
    # What is shown is decided by PlanPolicy::CatalogScope: listed, active, and open to this person (some plans are for members or
    # subscribers only). Any other id is a 404, so an unlisted or limited plan does not reveal that it exists.
    class CatalogController < ApplicationController
      include OwnerScoped

      skip_before_action :authenticate_user!, raise: false

      after_action :verify_authorized
      after_action :verify_policy_scoped

      def index
        authorize BetterTogether::Billing::Plan, :catalog?
        @plans = catalog_plans.order(:amount_cents, :identifier)
      end

      def show
        @plan = catalog_plans.find_by(id: params[:id])
        return skip_authorization_and_not_found unless @plan

        authorize @plan, :catalog_show?
      end

      private

      # Only what this person may see: a plan that is unlisted, or limited to an audience they are not in, is simply not there.
      def catalog_plans
        policy_scope(BetterTogether::Billing::Plan, policy_scope_class: BetterTogether::Billing::PlanPolicy::CatalogScope)
      end

      def skip_authorization_and_not_found
        skip_authorization
        render_not_found
      end
    end
  end
end

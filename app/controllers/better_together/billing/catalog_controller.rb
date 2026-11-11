# frozen_string_literal: true

module BetterTogether
  module Billing
    # The public catalog: the plans a steward has listed, for anyone to read, each with a button to buy it.
    # Reading needs no sign-in (buying does, at checkout). Billing off for the platform is a 404, as everywhere in billing.
    # Only listed, active plans are reachable; any other id is a 404 so unlisted plans stay unlisted.
    class CatalogController < ApplicationController
      include OwnerScoped

      skip_before_action :authenticate_user!, raise: false

      def index
        @plans = billing_owner.billing_plans.listed.order(:amount_cents, :identifier)
      end

      def show
        @plan = billing_owner.billing_plans.listed.find_by(id: params[:id])
        render_not_found unless @plan
      end
    end
  end
end

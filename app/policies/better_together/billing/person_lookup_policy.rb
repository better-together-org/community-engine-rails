# frozen_string_literal: true

module BetterTogether
  module Billing
    # Who may search this platform's members from a billing screen: those who may manage its billing, through the
    # same #manage_billing? question as the screens that use the search (store credit, sales in person).
    class PersonLookupPolicy < OwnerPolicy
      def index? = manage_billing?
    end
  end
end

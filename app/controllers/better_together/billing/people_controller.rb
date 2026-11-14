# frozen_string_literal: true

module BetterTogether
  module Billing
    # The search behind every billing screen that picks a person (the store credit lookup, the buyer of a sale in
    # person). Answers the select's ajax call with [{ value:, text: }]: at most 20 members of this platform whose
    # name contains the term or whose handle starts with it. Only a steward of the platform may search.
    class PeopleController < ApplicationController
      include OwnerScoped
      include PersonLookup

      after_action :verify_authorized

      def index
        authorize BetterTogether::Person, :index?, policy_class: PersonLookupPolicy
        render json: matching_people(params[:search].to_s.strip).limit(PEOPLE_LIMIT).map { |person|
          { value: person.id, text: person.select_option_title }
        }
      end
    end
  end
end

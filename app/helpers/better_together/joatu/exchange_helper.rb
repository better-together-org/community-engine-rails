# frozen_string_literal: true

module BetterTogether
  module Joatu
    module ExchangeHelper # rubocop:todo Style/Documentation
      # Should the "Respond with Request" button be visible for the current person?
      # - hide when there's no current_person
      # - hide when the current_person is the creator of the offer
      # - hide when the current_person has already responded to the offer
      # - hide when the current_person already has an agreement involving the offer
      # - hide when the offer itself is a response to one of the current_person's Requests
      # rubocop:todo Metrics/PerceivedComplexity
      # rubocop:todo Metrics/MethodLength
      # rubocop:todo Metrics/AbcSize
      def respond_with_request_visible?(offer) # rubocop:todo Metrics/CyclomaticComplexity, Metrics/AbcSize, Metrics/MethodLength, Metrics/PerceivedComplexity
        return false unless defined?(current_person) && current_person
        return false if offer.creator == current_person

        # has user already responded with a Request to this Offer?
        user_has_responded = offer.response_links_as_source.any? do |rl|
          rl.response.is_a?(BetterTogether::Joatu::Request) && rl.response.creator == current_person
        end
        return false if user_has_responded

        # any agreement involving this offer where the other party is the current person
        user_agreement = offer.agreements.detect do |agr|
          (agr.request && agr.request.creator == current_person) || (agr.offer && agr.offer.creator == current_person)
        end
        return false if user_agreement.present?

        # if this offer is itself a response to one of the current_person's Requests, hide the button
        return false if is_response_to_my_request?(offer)

        true
      end
      # rubocop:enable Metrics/AbcSize
      # rubocop:enable Metrics/MethodLength
      # rubocop:enable Metrics/PerceivedComplexity

      # Should the "Respond with Offer" button be visible for the current person?
      # Symmetric to respond_with_request_visible?
      # - hide when the request itself is a response to one of the current_person's Offers
      # rubocop:todo Metrics/PerceivedComplexity
      # rubocop:todo Metrics/MethodLength
      # rubocop:todo Metrics/AbcSize
      def respond_with_offer_visible?(request) # rubocop:todo Metrics/CyclomaticComplexity, Metrics/AbcSize, Metrics/MethodLength, Metrics/PerceivedComplexity
        return false unless defined?(current_person) && current_person
        return false if request.creator == current_person

        # has user already responded with an Offer to this Request?
        user_has_responded = request.response_links_as_source.any? do |rl|
          rl.response.is_a?(BetterTogether::Joatu::Offer) && rl.response.creator == current_person
        end
        return false if user_has_responded

        # any agreement involving this request where the other party is the current person
        user_agreement = request.agreements.detect do |agr|
          (agr.request && agr.request.creator == current_person) || (agr.offer && agr.offer.creator == current_person)
        end
        return false if user_agreement.present?

        # if this request is itself a response to one of the current_person's Offers, hide the button
        return false if is_response_to_my_offer?(request)

        true
      end
      # rubocop:enable Metrics/AbcSize
      # rubocop:enable Metrics/MethodLength
      # rubocop:enable Metrics/PerceivedComplexity

      # Is the given Offer itself a response to a Request owned by current_person?
      def is_response_to_my_request?(offer) # rubocop:todo Naming/PredicatePrefix
        return false unless defined?(current_person) && current_person

        offer.response_links_as_response.any? do |rl|
          rl.source.is_a?(BetterTogether::Joatu::Request) && rl.source.creator == current_person
        end
      end

      # Is the given Request itself a response to an Offer owned by current_person?
      def is_response_to_my_offer?(request) # rubocop:todo Naming/PredicatePrefix
        return false unless defined?(current_person) && current_person

        request.response_links_as_response.any? do |rl|
          rl.source.is_a?(BetterTogether::Joatu::Offer) && rl.source.creator == current_person
        end
      end

      # Find an Agreement involving the given resource where the other party is the current person.
      # Returns the Agreement or nil.
      def agreement_for_current_person(resource)
        return nil unless defined?(current_person) && current_person

        resource.agreements.detect do |agr|
          (agr.request && agr.request.creator == current_person) || (agr.offer && agr.offer.creator == current_person)
        end
      end
    end
  end
end

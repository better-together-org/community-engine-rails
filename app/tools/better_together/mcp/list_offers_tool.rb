# frozen_string_literal: true

module BetterTogether
  module Mcp
    # MCP Tool to list Joatu offers
    # Respects Joatu exchange policies and response link visibility
    class ListOffersTool < ApplicationTool
      description 'List open Joatu offers (things people are willing to provide)'

      arguments do
        optional(:status)
          .filled(:string)
          .description('Filter by status: open, matched, fulfilled, closed')
        optional(:urgency)
          .filled(:string)
          .description('Filter by urgency: low, normal, high, critical')
        optional(:limit)
          .filled(:integer)
          .description('Maximum number of results to return (default: 20)')
      end

      # List offers accessible to the current user
      # @param status [String] Optional status filter
      # @param urgency [String] Optional urgency filter
      # @param limit [Integer] Maximum results (default: 20)
      # @return [String] JSON array of offer objects
      def call(status: nil, urgency: nil, limit: 20)
        with_timezone_scope do
          offers = fetch_offers(status, urgency, limit)
          result = JSON.generate(offers.map { |offer| serialize_offer(offer) })

          log_invocation('list_offers', { status: status, urgency: urgency, limit: limit }, result.bytesize)
          result
        end
      end

      private

      def fetch_offers(status, urgency, limit)
        scope = policy_scope(BetterTogether::Joatu::Offer)
        scope = scope.where(status: status) if status.present?
        scope = scope.where(urgency: urgency) if urgency.present?
        scope.order(created_at: :desc).limit([limit, 100].min)
      end

      def serialize_offer(offer)
        {
          id: offer.id,
          name: offer.name,
          status: offer.status,
          urgency: offer.urgency,
          slug: offer.slug,
          creator_id: offer.creator_id,
          created_at: offer.created_at.iso8601,
          updated_at: offer.updated_at.iso8601
        }
      end
    end
  end
end

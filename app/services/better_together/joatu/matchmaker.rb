# frozen_string_literal: true

module BetterTogether
  module Joatu
    # Matchmaker finds offers or requests that align with a given record
    class Matchmaker
      # rubocop:disable Layout/MultilineMethodCallIndentation
      # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
      def self.match(record)
        case record
        when BetterTogether::Joatu::Request
          BetterTogether::Joatu::Offer.status_open
            .joins(:categories)
            .where(
              BetterTogether::Joatu::Category.table_name => {
                id: record.category_ids
              }
            )
            .where.not(creator_id: record.creator_id)
            .distinct
        when BetterTogether::Joatu::Offer
          BetterTogether::Joatu::Request.status_open
            .joins(:categories)
            .where(
              BetterTogether::Joatu::Category.table_name => {
                id: record.category_ids
              }
            )
            .where.not(creator_id: record.creator_id)
            .distinct
        else
          raise ArgumentError, 'Unknown matchable record'
        end
      end
      # rubocop:enable Metrics/AbcSize, Metrics/MethodLength
      # rubocop:enable Layout/MultilineMethodCallIndentation
    end
  end
end

# frozen_string_literal: true

module BetterTogether
  module Joatu
    # Matchmaker finds offers or requests that align with a given record
    class Matchmaker
      # Returns the opposite type matches for a request or offer
      # - If given a Request -> returns matching Offers
      # - If given an Offer   -> returns matching Requests
      def self.match(record) # rubocop:todo Metrics/AbcSize
        case record
        when BetterTogether::Joatu::Request
          offers = BetterTogether::Joatu::Offer.status_open
          offers = offers.joins(:categories)
                         .where(BetterTogether::Joatu::Category.table_name => { id: record.category_ids }) if record.category_ids.any?

          offers = offers.where(target_type: record.target_type)
          offers = offers.where(target_id: record.target_id) if record.target_id.present?
          offers = offers.where(target_id: nil) if record.target_id.blank?

          offers.where.not(creator_id: record.creator_id).distinct
        when BetterTogether::Joatu::Offer
          requests = BetterTogether::Joatu::Request.status_open
          requests = requests.joins(:categories)
                             .where(BetterTogether::Joatu::Category.table_name => { id: record.category_ids }) if record.category_ids.any?

          requests = requests.where(target_type: record.target_type)
          requests = requests.where(target_id: record.target_id) if record.target_id.present?
          requests = requests.where(target_id: nil) if record.target_id.blank?

          requests.where.not(creator_id: record.creator_id).distinct
        else
          raise ArgumentError, "Unsupported record type: #{record.class.name}"
        end
      end
    end
  end
end

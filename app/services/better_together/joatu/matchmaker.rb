# frozen_string_literal: true

module BetterTogether
  module Joatu
    # Matchmaker finds offers or requests that align with a given record
    class Matchmaker
      def self.match(request) # rubocop:todo Metrics/AbcSize
        offers = BetterTogether::Joatu::Offer.status_open
        if request.category_ids.any?
          offers = offers.joins(:categories)
                         .where(BetterTogether::Joatu::Category.table_name => { id: request.category_ids })
        end

        offers = offers.where(target_type: request.target_type)
        offers = offers.where(target_id: request.target_id) if request.target_id.present?
        offers = offers.where(target_id: nil) if request.target_id.blank?

        offers.where.not(creator_id: request.creator_id).distinct
      end
      # rubocop:enable Metrics/AbcSize, Metrics/MethodLength
      # rubocop:enable Layout/MultilineMethodCallIndentation
    end
  end
end

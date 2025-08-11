# frozen_string_literal: true

module BetterTogether
  module Joatu
    # Matchmaker finds offers that align with a given request
    class Matchmaker
      def self.match(request)
        BetterTogether::Joatu::Offer.status_open
                                    .where(target_type: request.target_type,
                                           target_id: request.target_id)
                                    .joins(:categories)
                                    .where(BetterTogether::Joatu::Category.table_name => { id: request.category_ids })
                                    .where.not(creator_id: request.creator_id)
                                    .distinct
      end
    end
  end
end

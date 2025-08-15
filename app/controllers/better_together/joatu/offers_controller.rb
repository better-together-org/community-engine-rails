# frozen_string_literal: true

module BetterTogether
  module Joatu
    # CRUD for BetterTogether::Joatu::Offer
    class OffersController < FriendlyResourceController
      def index
        @offers = BetterTogether::Joatu::SearchFilter.call(
          resource_class:,
          relation: resource_collection,
          params: params
        )

        # Build options for the filter form
        @category_options = BetterTogether::Joatu::CategoryOptions.call
      end
      protected

      def resource_class
        ::BetterTogether::Joatu::Offer
      end

      def param_name
        :offer
      end

      def resource_params
        super.tap do |attrs|
          attrs[:creator_id] ||= helpers.current_person&.id
          provided = Array(attrs[:category_ids]).reject(&:blank?)
          if provided.empty? && BetterTogether::Joatu::Category.exists?
            attrs[:category_ids] = [BetterTogether::Joatu::Category.first.id]
          end
        end
      end
    end
  end
end

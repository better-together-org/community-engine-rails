# frozen_string_literal: true

module BetterTogether
  module Billing
    module Orders
      # Whether what is being bought can be sold to this order: it is a kind of thing that can be bought, is for sale
      # (a renewal may be for something no longer for sale), belongs to the platform and the seller, and all of it is
      # in one currency. Says why not, or nil.
      class LineProblem
        def initialize(platform:, seller:, renewal: false)
          @platform = platform
          @seller = seller
          @renewal = renewal
        end

        def for(purchasables)
          purchasables.each do |purchasable|
            problem = problem_with(purchasable)
            return problem if problem
          end
          'all lines must be in the same currency' if purchasables.map(&:purchasable_currency).uniq.size > 1
        end

        private

        attr_reader :platform, :seller, :renewal

        def problem_with(purchasable)
          return 'that cannot be bought' unless Purchasable.model_names.include?(purchasable.class.name)
          return 'that is not for sale' unless renewal || purchasable.purchasable?
          return 'that belongs to another platform' if purchasable.try(:platform_id) != platform.id

          'that is sold by someone else' unless same_seller?(purchasable)
        end

        def same_seller?(purchasable)
          return seller.nil? if purchasable.try(:seller_id).blank?

          seller.present? && purchasable.seller_type == seller.class.name && purchasable.seller_id == seller.id
        end
      end
    end
  end
end

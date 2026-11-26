# frozen_string_literal: true

module BetterTogether
  module Billing
    class TaxReport
      # Whose sales a report covers: everyone's on the platform, the platform's own, or one seller's. A seller is named
      # by its type and id; the type must be one that may sell, and the seller is never loaded from the name, only
      # matched by its columns.
      class Owner
        UUID = /\A\h{8}-\h{4}-\h{4}-\h{4}-\h{12}\z/

        attr_reader :kind, :seller_type, :seller_id

        def self.all = new('all')

        def self.platform = new('platform')

        # "all", "platform" or "Type:id"; anything else is all.
        def self.parse(value)
          text = value.to_s
          return platform if text == 'platform'

          type, _colon, id = text.rpartition(':')
          return new('seller', seller_type: type, seller_id: id) if SellerScoped.assignable_types.include?(type) && id.to_s.match?(UUID)

          all
        end

        def self.for_seller(seller) = new('seller', seller_type: seller.class.name, seller_id: seller.id)

        def initialize(kind, seller_type: nil, seller_id: nil)
          @kind = kind
          @seller_type = seller_type
          @seller_id = seller_id
        end

        def key = seller? ? "#{seller_type}:#{seller_id}" : kind

        def seller? = kind == 'seller'

        def all? = kind == 'all'

        def platform? = kind == 'platform'

        # The condition narrowing the orders table to this owner (nil when it covers everyone).
        def condition(orders)
          return if all?
          return orders[:seller_id].eq(nil) if platform?

          orders[:seller_type].eq(seller_type).and(orders[:seller_id].eq(seller_id))
        end
      end
    end
  end
end

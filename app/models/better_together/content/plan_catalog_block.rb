# frozen_string_literal: true

module BetterTogether
  module Content
    # Shows the platform's public billing plans as cards, each with its price and a buy button.
    # Which plans a visitor sees is decided by the policy (listed, active, and for their audience),
    # so the block never reveals a plan the catalog page would not.
    class PlanCatalogBlock < Block
      include Translatable

      translates :heading, type: :string

      store_attributes :content_data do
        item_limit Integer, default: 6
      end

      validates :item_limit, numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: 24 }

      def self.extra_permitted_attributes
        super + %i[heading item_limit]
      end
    end
  end
end

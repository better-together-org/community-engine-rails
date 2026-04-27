# frozen_string_literal: true

# Add optional C3 pricing to Joatu Offers and Requests.
# C3 pricing is optional — exchanges can still be direct barter via Joatu.
# When c3_price_millitokens is set on an Offer, it means "I want X C3 for this service".
# When c3_budget_millitokens is set on a Request, it means "I'll pay up to X C3".
class AddC3PricingToJoatuOffersRequests < ActiveRecord::Migration[7.2]
  def change
    if table_exists?(:better_together_joatu_offers)
      unless column_exists?(:better_together_joatu_offers, :c3_price_millitokens)
        add_column :better_together_joatu_offers, :c3_price_millitokens, :bigint
      end
      unless column_exists?(:better_together_joatu_offers, :c3_price_currency)
        add_column :better_together_joatu_offers, :c3_price_currency, :string, default: 'C3'
      end
    end

    return unless table_exists?(:better_together_joatu_requests)

    unless column_exists?(:better_together_joatu_requests, :c3_budget_millitokens)
      add_column :better_together_joatu_requests, :c3_budget_millitokens, :bigint
    end
    return if column_exists?(:better_together_joatu_requests, :c3_budget_currency)

    add_column :better_together_joatu_requests, :c3_budget_currency, :string, default: 'C3'
  end
end

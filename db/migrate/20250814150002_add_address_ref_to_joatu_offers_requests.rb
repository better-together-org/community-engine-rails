# frozen_string_literal: true

# Associates JOATU offers and requests with an Address record
class AddAddressRefToJoatuOffersRequests < ActiveRecord::Migration[7.0]
  def change
    add_reference :better_together_joatu_offers, :address,
                  type: :uuid,
                  foreign_key: { to_table: :better_together_addresses }

    add_reference :better_together_joatu_requests, :address,
                  type: :uuid,
                  foreign_key: { to_table: :better_together_addresses }
  end
end

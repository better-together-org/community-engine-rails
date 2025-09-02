# frozen_string_literal: true

class AddUniqueIndexesToJoatuLinksAndAgreements < ActiveRecord::Migration[7.1] # rubocop:todo Style/Documentation
  def change
    # Ensure one Agreement per Offer/Request pair
    add_index :better_together_joatu_agreements,
              %i[offer_id request_id],
              unique: true,
              name: 'bt_joatu_agreements_unique_offer_request'

    # Ensure one ResponseLink per exact source/response pair
    add_index :better_together_joatu_response_links,
              %i[source_type source_id response_type response_id],
              unique: true,
              name: 'bt_joatu_response_links_unique_pair'
  end
end

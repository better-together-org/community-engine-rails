# frozen_string_literal: true

class AddPartialUniqueIndexesForAcceptedAgreements < ActiveRecord::Migration[7.1] # rubocop:todo Style/Documentation
  def change
    add_index :better_together_joatu_agreements,
              :offer_id,
              unique: true,
              where: "status = 'accepted'",
              name: 'bt_joatu_agreements_one_accepted_per_offer'

    add_index :better_together_joatu_agreements,
              :request_id,
              unique: true,
              where: "status = 'accepted'",
              name: 'bt_joatu_agreements_one_accepted_per_request'
  end
end

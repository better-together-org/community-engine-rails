# Adds polymorphic target references to Joatu requests and offers
# frozen_string_literal: true

class AddTargetToJoatuRequestsAndOffers < ActiveRecord::Migration[7.1]
  def change
    change_table :better_together_joatu_requests, bulk: true do |t|
      t.string :target_type
      t.uuid :target_id
      t.index %i[target_type target_id], name: 'index_bt_joatu_requests_on_target'
    end

    change_table :better_together_joatu_offers, bulk: true do |t|
      t.string :target_type
      t.uuid :target_id
      t.index %i[target_type target_id], name: 'index_bt_joatu_offers_on_target'
    end
  end
end

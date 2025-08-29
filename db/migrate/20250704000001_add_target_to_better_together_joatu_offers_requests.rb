# frozen_string_literal: true

# Adds polymorphic target references to Joatu offers and requests
class AddTargetToBetterTogetherJoatuOffersRequests < ActiveRecord::Migration[7.1]
  def change
    change_table :better_together_joatu_offers do |t|
      t.bt_references :target, polymorphic: true, index: { name: 'bt_joatu_offers_on_target' }
    end

    change_table :better_together_joatu_requests do |t|
      t.bt_references :target, polymorphic: true, index: { name: 'bt_joatu_requests_on_target' }
    end
  end
end

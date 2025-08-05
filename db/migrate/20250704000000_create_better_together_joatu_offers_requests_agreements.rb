# frozen_string_literal: true

# Creates tables for BetterTogether::Joatu models
class CreateBetterTogetherJoatuOffersRequestsAgreements < ActiveRecord::Migration[7.1]
  # rubocop:disable Metrics/MethodLength
  def change
    create_bt_table :joatu_offers do |t|
      t.bt_creator
      t.string :status, null: false, default: 'open'
    end

    create_bt_table :joatu_requests do |t|
      t.bt_creator
      t.string :status, null: false, default: 'open'
    end

    create_bt_table :joatu_agreements do |t|
      t.bt_references :offer,   target_table: :better_together_joatu_offers,   null: false,
                                index: { name: 'bt_joatu_agreements_by_offer' }
      t.bt_references :request, target_table: :better_together_joatu_requests, null: false,
                                index: { name: 'bt_joatu_agreements_by_request' }
      t.bt_emoji_text :terms
      t.string :value
      t.string :status, null: false, default: 'pending'
    end
  end
  # rubocop:enable Metrics/MethodLength
end

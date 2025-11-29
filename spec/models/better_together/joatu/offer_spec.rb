# frozen_string_literal: true

require 'rails_helper'

module BetterTogether
  module Joatu
    RSpec.describe Offer do
      subject(:offer) { build(:better_together_joatu_offer) }

      it 'is valid without a target' do
        expect(offer).to be_valid
      end

      it 'is valid with a target' do
        offer_with_target = build(:better_together_joatu_offer, :with_target)
        expect(offer_with_target).to be_valid
      end

      it 'is valid with only a target_type' do
        offer_with_type = build(:better_together_joatu_offer, :with_target_type)
        expect(offer_with_type).to be_valid
      end

      it 'is invalid without a creator' do
        offer.creator = nil
        expect(offer).not_to be_valid
      end

      it 'is invalid without target_type when target_id is set' do # rubocop:todo RSpec/NoExpectationExample
        offer.target_id = SecureRandom.uuid
        offer.target_type = nil
      end

      describe 'translations validation side-effects' do
        it 'does not instantiate blank string translations for other locales when assigning name_en and validating' do
          prev_locales = I18n.available_locales

          begin
            offer = build(:better_together_joatu_offer)

            # Assign only the English translation
            offer.name_en = 'hello world'

            # Validate; should not spawn other-locale translations as a side effect
            offer.valid?
            other_locale_translations = offer.string_translations.select do |t|
              %w[name slug].include?(t.key) && t.locale != 'en'
            end
            expect(other_locale_translations).to be_empty

            # Ensure we did set the English name translation in-memory
            en_name = offer.string_translations.detect { |t| t.key == 'name' && t.locale == 'en' }
            expect(en_name&.value).to eq('hello world')
          ensure
            I18n.available_locales = prev_locales
          end
        end
      end

      it 'is invalid without categories' do
        offer.categories = []
        expect(offer).not_to be_valid
      end
    end
  end
end

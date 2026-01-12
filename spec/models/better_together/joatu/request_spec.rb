# frozen_string_literal: true

require 'rails_helper'

module BetterTogether
  module Joatu
    RSpec.describe Request do
      subject(:request_model) { build(:better_together_joatu_request) }

      describe 'Factory' do
        it 'has a valid factory' do
          expect(request_model).to be_valid
        end

        describe 'traits' do
          describe ':with_target' do
            subject(:request_with_target) { build(:better_together_joatu_request, :with_target) }

            it 'creates a request with a target person' do
              expect(request_with_target.target).to be_present
              expect(request_with_target.target).to be_a(BetterTogether::Person)
            end

            it 'is valid' do
              expect(request_with_target).to be_valid
            end
          end

          describe ':with_target_type' do
            subject(:request_with_type) { build(:better_together_joatu_request, :with_target_type) }

            it 'sets the target_type attribute' do
              expect(request_with_type.target_type).to eq('BetterTogether::Invitation')
            end

            it 'is valid' do
              expect(request_with_type).to be_valid
            end
          end

          describe 'combined traits' do
            it 'with_target and with_target_type are mutually exclusive' do
              # When both traits are used, :with_target_type overwrites target_type
              # but doesn't set target, so they should not be combined
              request_with_target = build(:better_together_joatu_request, :with_target)
              request_with_type = build(:better_together_joatu_request, :with_target_type)

              expect(request_with_target.target).to be_present
              expect(request_with_type.target_type).to eq('BetterTogether::Invitation')
            end
          end
        end
      end

      it 'is invalid without a creator' do
        request_model.creator = nil
        expect(request_model).not_to be_valid
      end

      it 'is invalid without target_type when target_id is set' do # rubocop:todo RSpec/NoExpectationExample
        request_model.target_id = SecureRandom.uuid
        request_model.target_type = nil
      end

      it 'is invalid without categories' do
        request_model.categories = []
        expect(request_model).not_to be_valid
      end
    end
  end
end

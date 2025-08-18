# frozen_string_literal: true

# spec/models/better_together/wizard_spec.rb

require 'rails_helper'

module BetterTogether
  RSpec.describe Wizard do
    subject(:wizard) { build(:better_together_wizard) }

    describe 'Factory' do
      it 'has a valid factory' do
        expect(wizard).to be_valid
      end
    end

    describe 'ActiveRecord associations' do
      it { is_expected.to have_many(:wizard_step_definitions).dependent(:destroy) }
      it { is_expected.to have_many(:wizard_steps).dependent(:destroy) }
    end

    describe 'ActiveModel validations' do
      it { is_expected.to validate_presence_of(:name) }

      # TODO: identifier validations are primarily handled by db. unsure how to have these pass properly
      # it { is_expected.to validate_presence_of(:identifier) }
      # it { is_expected.to validate_uniqueness_of(:identifier) }
      # it { is_expected.to validate_length_of(:identifier).is_at_most(100) }
      it { is_expected.to validate_numericality_of(:max_completions).only_integer.is_greater_than_or_equal_to(0) }
      it { is_expected.to validate_numericality_of(:current_completions).only_integer.is_greater_than_or_equal_to(0) }
    end

    describe 'Attributes' do
      it { is_expected.to respond_to(:name) }
      it { is_expected.to respond_to(:slug) }
      it { is_expected.to respond_to(:identifier) }
      it { is_expected.to respond_to(:description) }
      it { is_expected.to respond_to(:max_completions) }
      it { is_expected.to respond_to(:current_completions) }
      it { is_expected.to respond_to(:first_completed_at) }
      it { is_expected.to respond_to(:last_completed_at) }
      it { is_expected.to respond_to(:success_message) }
      it { is_expected.to respond_to(:success_path) }
      it { is_expected.to respond_to(:protected) }
    end

    describe 'Methods' do
      describe '#limited_completions?' do
        context 'when max_completions is positive' do
          before { wizard.max_completions = 1 }

          it 'returns true' do
            expect(wizard.limited_completions?).to be true
          end
        end

        context 'when max_completions is zero' do
          before { wizard.max_completions = 0 }

          it 'returns false' do
            expect(wizard.limited_completions?).to be false
          end
        end
      end

      describe '#mark_completed' do
        context 'when current completions is less than max completions' do
          before do
            wizard.max_completions = 2
            wizard.current_completions = 1
          end

          it 'increases current completions and updates completed at' do # rubocop:todo RSpec/MultipleExpectations
            wizard.mark_completed
            expect(wizard.current_completions).to eq(2)
            expect(wizard.last_completed_at).not_to be_nil
          end
        end

        context 'when current completions is equal to max completions' do
          before do
            wizard.max_completions = 1
            wizard.current_completions = 1
          end

          it 'does not change current completions' do
            wizard.mark_completed
            expect(wizard.current_completions).to eq(1)
          end
        end
      end

      describe '#completed?' do
        context 'when all wizard steps are completed' do
          before do
            # Assuming the existence of a wizard_step_definitions and wizard_steps factory
            create_list(:wizard_step_definition, 3, wizard:)
            wizard.wizard_step_definitions.each do |step_definition|
              create(:wizard_step, wizard:, wizard_step_definition: step_definition, completed: true)
            end
            wizard.max_completions = 1
          end

          it 'returns true' do
            expect(wizard.completed?).to be true
          end
        end

        context 'when not all wizard steps are completed' do
          before do
            create_list(:wizard_step_definition, 3, wizard:)
            create(:wizard_step, wizard:, wizard_step_definition: wizard.wizard_step_definitions.first,
                                 completed: true)
            create(:wizard_step, wizard:, wizard_step_definition: wizard.wizard_step_definitions.second,
                                 completed: false)
          end

          it 'returns false' do
            expect(wizard.completed?).to be false
          end
        end
      end
    end
  end
end

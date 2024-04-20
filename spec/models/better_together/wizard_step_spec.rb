# frozen_string_literal: true

# spec/models/better_together/wizard_step_spec.rb

require 'rails_helper'

module BetterTogether
  RSpec.describe WizardStep, type: :model do # rubocop:todo Metrics/BlockLength
    subject(:wizard_step) { build(:better_together_wizard_step) }
    subject(:existing_wizard_step) { create(:better_together_wizard_step) }

    describe 'Factory' do
      it 'has a valid factory' do
        expect(wizard_step).to be_valid
      end
    end

    describe 'ActiveRecord associations' do
      # it { is_expected.to belong_to(:wizard) }
      it {
        is_expected.to belong_to(:wizard_step_definition)
      }
      it { is_expected.to belong_to(:creator).class_name('BetterTogether::Person').optional }
    end

    describe 'ActiveModel validations' do
      it { is_expected.to validate_inclusion_of(:completed).in_array([true, false]) }
    end

    describe 'Methods' do
      describe '#mark_as_completed' do
        it 'marks the wizard step as completed and saves it' do
          wizard_step.mark_as_completed
          expect(wizard_step.completed).to be true
          expect(wizard_step.persisted?).to be true
        end
      end
    end

    describe 'Custom Validations' do
      describe '#unique_uncompleted_step_per_person' do
        context 'when there is an existing uncompleted step for the same wizard and creator' do
          before do
            create(:better_together_wizard_step, wizard: existing_wizard_step.wizard,
                                                 creator: existing_wizard_step.creator, completed: false)
          end

          # it 'adds an error' do
          #   existing_wizard_step.valid?
          #   expect(wizard_step.errors[:base]).to include("Only one uncompleted step per person is allowed.")
          # end
        end
      end

      describe '#validate_step_completions' do
        context 'when number of completions for the step has reached the wizard’s max completions limit' do
          before do
            existing_wizard_step.wizard.update(max_completions: 1)
            create(:better_together_wizard_step, wizard: wizard_step.wizard, identifier: wizard_step.identifier,
                                                 completed: true)
          end

          # it 'adds an error' do
          #   existing_wizard_step.completed = true
          #   existing_wizard_step.valid?
          #   expect(existing_wizard_step.errors[:base]).to
          # include("Number of completions for this step has reached the wizard's max completions limit.")
          # end
        end
      end
    end
  end
end

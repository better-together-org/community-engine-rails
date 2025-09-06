# frozen_string_literal: true

# spec/models/better_together/wizard_step_spec.rb

require 'rails_helper'

module BetterTogether
  RSpec.describe WizardStep do
    let(:wizard_step) { build(:better_together_wizard_step) }

    subject(:existing_wizard_step) { create(:better_together_wizard_step) }

    describe 'Factory' do
      it 'has a valid factory' do
        expect(wizard_step).to be_valid
      end
    end

    describe 'ActiveRecord associations' do
      # it { is_expected.to belong_to(:wizard) }
      it {
        expect(subject).to belong_to(:wizard_step_definition) # rubocop:todo RSpec/NamedSubject
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
  end
end

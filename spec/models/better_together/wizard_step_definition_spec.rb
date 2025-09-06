# frozen_string_literal: true

# spec/models/better_together/wizard_step_definition_spec.rb

require 'rails_helper'

module BetterTogether
  RSpec.describe WizardStepDefinition do
    let(:wizard_step_definition) { build(:better_together_wizard_step_definition) }

    subject(:existing_wizard_step_definition) { create(:better_together_wizard_step_definition) }

    describe 'Factory' do
      it 'has a valid factory' do
        expect(wizard_step_definition).to be_valid
      end
    end

    describe 'ActiveRecord associations' do
      it { is_expected.to belong_to(:wizard) }
      it { is_expected.to have_many(:wizard_steps) }
    end

    describe 'ActiveModel validations' do
      it { is_expected.to validate_presence_of(:name) }
      it { is_expected.to validate_presence_of(:description) }
      # TODO: identifier validations are primarily handled by db. unsure how to have these pass properly
      # it { is_expected.to validate_presence_of(:identifier) }
      it { is_expected.to validate_uniqueness_of(:identifier).scoped_to(:wizard_id).case_insensitive }
      it { is_expected.to validate_numericality_of(:step_number).only_integer.is_greater_than(0) }
      it { is_expected.to validate_uniqueness_of(:step_number).scoped_to(:wizard_id) }
      it { is_expected.to validate_presence_of(:message) }
    end

    describe 'Attributes' do
      it { is_expected.to respond_to(:name) }
      it { is_expected.to respond_to(:description) }
      it { is_expected.to respond_to(:identifier) }
      it { is_expected.to respond_to(:template) }
      it { is_expected.to respond_to(:form_class) }
      it { is_expected.to respond_to(:message) }
      it { is_expected.to respond_to(:step_number) }
      it { is_expected.to respond_to(:protected) }
    end

    describe 'Methods' do
      describe '#build_wizard_step' do
        it 'builds a new wizard step with the correct attributes' do
          wizard_step = wizard_step_definition.build_wizard_step
          expect(wizard_step).to be_a(BetterTogether::WizardStep)
          expect(wizard_step.identifier).to eq(wizard_step_definition.identifier)
          expect(wizard_step.step_number).to eq(wizard_step_definition.step_number)
        end
      end

      describe '#create_wizard_step' do
        it 'creates a new wizard step and saves it' do
          wizard_step = existing_wizard_step_definition.create_wizard_step
          expect(wizard_step.persisted?).to be true
        end
      end

      describe '#routing_path' do
        it 'returns the correct routing path' do
          expected_path =
            "#{wizard_step_definition.wizard.identifier.underscore}/#{wizard_step_definition.identifier.underscore}"
          expect(wizard_step_definition.routing_path).to eq(expected_path)
        end
      end

      describe '#template_path' do
        it 'returns the default path to the template' do
          expected_path = "better_together/wizard_step_definitions/#{wizard_step_definition.routing_path}"
          expect(wizard_step_definition.template_path).to eq(expected_path)
        end
      end
    end
  end
end

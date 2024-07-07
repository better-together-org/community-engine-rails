# frozen_string_literal: true

# spec/factories/wizard_steps.rb

FactoryBot.define do
  factory :better_together_wizard_step,
          class: 'BetterTogether::WizardStep',
          aliases: %i[wizard_step] do
    id { SecureRandom.uuid }
    wizard_step_definition
    wizard { wizard_step_definition.wizard }
    association :creator, factory: :better_together_person
    identifier { wizard_step_definition.identifier }
    step_number { wizard_step_definition.step_number }
    completed { false }
  end
end

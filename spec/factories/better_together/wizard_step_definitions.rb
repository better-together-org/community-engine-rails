# frozen_string_literal: true

# spec/factories/wizard_step_definitions.rb

FactoryBot.define do
  factory :better_together_wizard_step_definition,
          class: 'BetterTogether::WizardStepDefinition',
          aliases: %i[wizard_step_definition] do
    bt_id { SecureRandom.uuid }
    wizard { create(:wizard) }
    name { Faker::Lorem.unique.sentence(word_count: 3) }
    description { Faker::Lorem.paragraph }
    identifier { name.parameterize }
    template { "template_#{Faker::Lorem.word}" }
    form_class { "FormClass#{Faker::Lorem.word}" }
    message { 'Please complete this next step.' }
    step_number { Faker::Number.unique.between(from: 1, to: 50) }
    protected { Faker::Boolean.boolean }
  end
end

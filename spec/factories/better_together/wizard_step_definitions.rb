# frozen_string_literal: true

# spec/factories/wizard_step_definitions.rb

FactoryBot.define do
  factory :better_together_wizard_step_definition,
          class: 'BetterTogether::WizardStepDefinition',
          aliases: %i[wizard_step_definition] do
    sequence(:id) { |_n| SecureRandom.uuid }
    wizard { create(:wizard) }
    name { Faker::Lorem.sentence(word_count: 3) }
    description { Faker::Lorem.paragraph }
    sequence(:identifier) { |n| "#{name.parameterize}-#{n}" }
    template { "template_#{Faker::Lorem.word}" }
    form_class { "FormClass#{Faker::Lorem.word}" }
    message { 'Please complete this next step.' }
    sequence(:step_number) { |n| n }
    protected { Faker::Boolean.boolean }
  end
end

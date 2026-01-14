# frozen_string_literal: true

# spec/factories/wizards.rb

FactoryBot.define do
  factory 'better_together/wizard',
          class: 'BetterTogether::Wizard',
          aliases: %i[better_together_wizard wizard] do
    id { SecureRandom.uuid }
    name { Faker::Lorem.unique.sentence(word_count: 3) }
    description { Faker::Lorem.paragraph }
    max_completions { 0 }
    current_completions { Faker::Number.between(from: 0, to: max_completions) }
    success_message { 'Thank you. You have successfully completed the wizard' }
    success_path { '/' }
    protected { Faker::Boolean.boolean }
  end
end

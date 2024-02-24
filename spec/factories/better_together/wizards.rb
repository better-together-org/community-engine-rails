# spec/factories/wizards.rb

FactoryBot.define do
  factory :better_together_wizard,
          class: 'BetterTogether::Wizard',
          aliases: %i[wizard] do
    bt_id { SecureRandom.uuid }
    name { Faker::Lorem.sentence(word_count: 3) }
    identifier { name.parameterize }
    description { Faker::Lorem.paragraph }
    max_completions { 0 }
    current_completions { Faker::Number.between(from: 0, to: max_completions) }
    success_message { 'Thank you. You have successfully completed the wizard' }
    success_path { '/' }
    protected { Faker::Boolean.boolean }
  end
end

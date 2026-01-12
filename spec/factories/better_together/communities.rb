# frozen_string_literal: true

FactoryBot.define do
  factory('better_together/community',
          class: 'BetterTogether::Community',
          aliases: %i[better_together_community community]) do
    id { Faker::Internet.uuid }
    name { Faker::Company.unique.name }
    description { Faker::Lorem.paragraphs(number: 3).join("\n\n") }
    privacy { 'private' }
    host { false }
    protected { false }
    identifier { Faker::Internet.unique.username(specifier: 10..20).parameterize }

    trait :creator do
      association :creator, factory: :person
    end

    trait :host do
      host { true }
    end
  end
end

# frozen_string_literal: true

FactoryBot.define do
  factory('better_together/community',
          class: 'BetterTogether::Community',
          aliases: %i[better_together_community community]) do
    id { Faker::Internet.uuid }
    identifier { Faker::Internet.unique.uuid }
    name { Faker::Company.name }
    description { Faker::Lorem.paragraphs(number: 3).join("\n\n") }
    privacy { 'private' }
    host { false }
    protected { false }
    slug { name.parameterize }

    trait :creator do
      association :creator, factory: :person
    end

    trait :host do
      host { true }
    end
  end
end

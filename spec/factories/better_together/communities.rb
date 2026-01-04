# frozen_string_literal: true

FactoryBot.define do
  factory('better_together/community',
          class: 'BetterTogether::Community',
          aliases: %i[better_together_community community]) do
    id { Faker::Internet.uuid }
    name { Faker::Company.name }
    description { Faker::Lorem.paragraphs(number: 3).join("\n\n") }
    privacy { 'private' }
    host { false }
    protected { false }
    # Let the model handle identifier/slug generation from name via the Identifier concern

    trait :creator do
      association :creator, factory: :person
    end

    trait :host do
      host { true }
    end
  end
end

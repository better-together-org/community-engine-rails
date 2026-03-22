# frozen_string_literal: true

FactoryBot.define do
  factory('better_together/community',
          class: 'BetterTogether::Community',
          aliases: %i[better_together_community community]) do
    id { Faker::Internet.uuid }
    name { "#{Faker::Company.name} #{SecureRandom.hex(4)}" }
    description { Faker::Lorem.paragraphs(number: 3).join("\n\n") }
    privacy { 'private' }
    host { false }
    protected { false }
    identifier { "community-#{SecureRandom.hex(10)}" }

    trait :creator do
      association :creator, factory: :person
    end

    trait :host do
      host { true }
    end
  end
end

# frozen_string_literal: true

module BetterTogether
  FactoryBot.define do
    factory :better_together_event, class: Event, aliases: %i[event] do
      name { Faker::Theater.play }
      description { Faker::Lorem.paragraphs(number: 3) }
      starts_at { nil }
      ends_at { nil }

      association :creator, factory: :person
    end
  end
end

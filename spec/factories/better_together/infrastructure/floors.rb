# frozen_string_literal: true

FactoryBot.define do
  factory(
    'better_together/infrastructure/floor',
    class: 'BetterTogether::Infrastructure::Floor',
    aliases: %i[better_together_infrastructure_floor floor]
  ) do
    id { Faker::Internet.uuid }
    name { "Floor #{Faker::Number.between(from: 1, to: 10)}" }
    description { Faker::Lorem.paragraph }
    level { Faker::Number.between(from: 1, to: 10) }
    building { association :better_together_infrastructure_building }
  end
end

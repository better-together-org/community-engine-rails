# frozen_string_literal: true

FactoryBot.define do
  factory(
    'better_together/infrastructure/room',
    class: 'BetterTogether::Infrastructure::Room',
    aliases: %i[better_together_infrastructure_room room]
  ) do
    id { Faker::Internet.uuid }
    name { "Room #{Faker::Number.between(from: 1, to: 100)}" }
    description { Faker::Lorem.paragraph }
    floor
  end
end

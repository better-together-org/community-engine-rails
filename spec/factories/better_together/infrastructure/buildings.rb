# frozen_string_literal: true

FactoryBot.define do
  factory(
    'better_together/infrastructure/building',
    class: 'BetterTogether::Infrastructure::Building',
    aliases: %i[better_together_infrastructure_building building]
  ) do
    id { Faker::Internet.uuid }
    name { Faker::Address.community }
    description { Faker::Lorem.paragraph }
    privacy { 'private' }

    address

    trait :with_floors do
      after(:create) do |building|
        create_list(:better_together_infrastructure_floor, 2, building: building)
      end
    end

    trait :with_rooms do
      after(:create) do |building|
        floor = create(:better_together_infrastructure_floor, building: building)
        create_list(:better_together_infrastructure_room, 3, floor: floor)
      end
    end
  end
end

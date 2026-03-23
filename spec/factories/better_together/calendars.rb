# frozen_string_literal: true

FactoryBot.define do
  factory('better_together/calendar',
          class: 'BetterTogether::Calendar',
          aliases: %i[better_together_calendar calendar]) do
    identifier { Faker::Internet.unique.uuid }
    name { Faker::Lorem.unique.words(number: 3).join(' ') }
    description { Faker::Lorem.paragraph }
    privacy { 'private' }
    protected { false }
    locale { 'en' }
    association :community, factory: :community
  end
end

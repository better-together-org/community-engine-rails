# frozen_string_literal: true

FactoryBot.define do
  factory('better_together/address',
          class: 'BetterTogether::Address',
          aliases: %i[better_together_address address]) do
    label { 'work' }
    physical { true }
    postal { false }
    line1 { '62 Broadway' }
    city_name { 'Corner Brook' }
    state_province_name { 'Newfoundland and Labrador' }
    postal_code { 'A2H 4C2' }
    country_name { 'Canada' }
    privacy { 'public' }

    trait :with_contact do
      association :contact_detail, factory: :contact_detail
    end
  end
end

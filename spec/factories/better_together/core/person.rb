require 'faker'

module BetterTogether
  module Core
    FactoryBot.define do
      factory :person, class: Person do
        given_name { Faker::Name.first_name }
        family_name { Faker::Name.last_name }
      end
    end
  end
end

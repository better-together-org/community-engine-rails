# frozen_string_literal: true

require 'faker'

module BetterTogether
  FactoryBot.define do
    factory :better_together_person, class: Person, aliases: %i[person inviter invitee creator author] do
      id { Faker::Internet.uuid }
      name { Faker::Name.name }
      description { Faker::Lorem.paragraphs(number: 3) }
      identifier { Faker::Internet.unique.username(specifier: 5..10) }

      community
    end
  end
end

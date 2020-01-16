require 'faker'

module BetterTogether
  module Community
    FactoryBot.define do
      factory :person, class: Person, aliases: [:inviter, :invitee, :creator] do
        given_name { Faker::Name.first_name }
        family_name { Faker::Name.last_name }
      end
    end
  end
end

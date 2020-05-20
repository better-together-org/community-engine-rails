require 'faker'

module BetterTogether
  module Community
    FactoryBot.define do
      factory :person, class: Person, aliases: [:inviter, :invitee, :creator] do
        name { Faker::Name.name }
      end
    end
  end
end

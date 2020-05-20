require 'faker'

module BetterTogether
  FactoryBot.define do
    factory :person, class: Person, aliases: [:inviter, :invitee, :creator, :author] do
      bt_id { Faker::Internet.uuid }
      name { Faker::Name.name }
    end
  end
end

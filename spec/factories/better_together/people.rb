require 'faker'

module BetterTogether
  FactoryBot.define do
    factory :better_together_person, class: Person, aliases: [:person, :inviter, :invitee, :creator, :author] do
      bt_id { Faker::Internet.uuid }
      name { Faker::Name.name }
    end
  end
end

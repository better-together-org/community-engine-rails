require 'faker'

module BetterTogether
  FactoryBot.define do
    factory :better_together_authorship, class: Authorship do
      bt_id { Faker::Internet.uuid }
      sort_order { 1 }
    end
  end
end

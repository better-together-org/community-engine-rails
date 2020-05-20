require 'faker'

module BetterTogether
  FactoryBot.define do
    factory :better_together_authorship, class: Authorship do
      bt_id { "MyString" }
      sort_order { 1 }
    end
  end
end

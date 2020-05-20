require 'faker'

module BetterTogether
  FactoryBot.define do
    factory :better_together_authorable, class: Authorable do
      bt_id { "MyString" }
      authorable
    end
  end
end

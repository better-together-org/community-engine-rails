require 'faker'

module BetterTogether
  FactoryBot.define do
    factory :better_together_author, class: Author do
      bt_id { "MyString" }
      author
    end
  end
end


module BetterTogether
  FactoryBot.define do
    factory :better_together_group, class: Group do
      bt_id { Faker::Internet.uuid }
      name { "MyString" }
      description { "MyText" }
      slug { "MyString" }
      group_privacy { "public" }
      creator
    end
  end
end


module BetterTogether
  module Community
    FactoryBot.define do
      factory :better_together_community_group, class: Group do
        name { "MyString" }
        description { "MyText" }
        slug { "MyString" }
        group_privacy { "public" }
        creator
      end
    end
  end
end

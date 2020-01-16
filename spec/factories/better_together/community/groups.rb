
module BetterTogether
  module Community
    FactoryBot.define do
      factory :better_together_community_group, class: Group do
        type { "" }
        name { "MyString" }
        description { "MyText" }
        slug { "MyString" }
        privacy_level { "MyString" }
        creator
      end
    end
  end
end

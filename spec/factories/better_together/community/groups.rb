FactoryBot.define do
  factory :better_together_community_group, class: 'Group' do
    type { "" }
    name { "MyString" }
    description { "MyText" }
    slug { "MyString" }
    creator { "" }
    privacy_level { "MyString" }
  end
end

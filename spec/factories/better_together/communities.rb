
FactoryBot.define do
  factory(
    :better_together_community,
    class: ::BetterTogether::Community,
      aliases: %i[community]
    ) do
    bt_id { Faker::Internet.uuid }
    name { "MyString" }
    description { "MyText" }
    slug { "MyString" }
    community_privacy { "public" }
    creator
  end
end

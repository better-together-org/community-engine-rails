FactoryBot.define do
  factory(
    :better_together_community,
    class: ::BetterTogether::Community,
    aliases: %i[community]
  ) do
    bt_id { Faker::Internet.uuid }
    name { Faker::Name.name }
    description { 'MyText' }
    privacy { 'public' }
    creator
  end
end

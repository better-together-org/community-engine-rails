FactoryBot.define do
  factory :better_together_post, class: 'BetterTogether::Post', aliases: %i[authorable] do
    bt_id { Faker::Internet.uuid }
    title { 'My title'}
    content { 'My content'}
  end
end

require 'faker'

FactoryBot.define do
  factory :better_together_user,
    class: ::BetterTogether::User,
    aliases: %i[user] do
    email { Faker::Internet.unique.email }
    password { Faker::Internet.password(min_length: 10, max_length: 20) }

    trait :confirmed do
      confirmed_at { Time.zone.now }
      confirmation_sent_at { Time.zone.now }
      confirmation_token { '12345' }
    end
  end
end

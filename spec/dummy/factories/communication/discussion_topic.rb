require 'faker'

FactoryBot.define do
  factory :discussion_topic, class: 'TheSeed::Communication::DiscussionTopic' do
    name { Faker::Hobbit.quote }
    description { Faker::Lorem.paragraph(5) }
  end
end

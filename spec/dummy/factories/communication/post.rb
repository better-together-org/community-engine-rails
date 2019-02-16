require 'faker'

FactoryBot.define do
  factory :post, class: 'TheSeed::Communication::Post' do
    title { Faker::Hobbit.quote }
    content { Faker::Lorem.paragraph(5) }
  end
end

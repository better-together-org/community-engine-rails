require 'faker'

FactoryBot.define do
  factory :person, class: 'TheSeed::Person' do
    name { Faker::BojackHorseman.character }
  end
end

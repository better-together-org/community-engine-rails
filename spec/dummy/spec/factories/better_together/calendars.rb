# frozen_string_literal: true

FactoryBot.define do
  factory :better_together_calendar, class: 'BetterTogether::Calendar' do
    identifier { 'MyString' }
    name { 'MyString' }
    description { 'MyText' }
    slug { 'MyString' }
    privacy { 'private' }
    protected { false }
    community
  end
end

# frozen_string_literal: true

FactoryBot.define do
  factory :content_link, class: 'BetterTogether::Content::Link' do
    link_type { 'website' }
    sequence(:url) { |n| "https://example.test/#{n}" }
    scheme { 'https' }
    host { URI.parse(url).host }
    external { false }
    valid_link { false }
  end
end

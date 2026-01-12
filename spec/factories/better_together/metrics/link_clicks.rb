# frozen_string_literal: true

FactoryBot.define do
  factory :metrics_link_click, class: 'BetterTogether::Metrics::LinkClick' do
    url { Faker::Internet.url(path: "/#{Faker::Internet.slug}") }
    page_url { Faker::Internet.url(path: "/#{Faker::Internet.slug}") }
    locale { I18n.available_locales.sample.to_s }
    clicked_at { Faker::Time.between(from: 15.days.ago, to: 1.day.ago) }
    internal { [true, false].sample }
  end
end

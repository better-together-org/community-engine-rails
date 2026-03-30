# frozen_string_literal: true

FactoryBot.define do
  factory :metrics_link_click, class: 'BetterTogether::Metrics::LinkClick' do
    url { Faker::Internet.url(path: "/#{Faker::Internet.slug}") }
    page_url { Faker::Internet.url(path: "/#{Faker::Internet.slug}") }
    platform { BetterTogether::Platform.find_by(host: true) || association(:better_together_platform, :host) }
    locale { I18n.available_locales.sample.to_s }
    logged_in { false }
    clicked_at { Faker::Time.between(from: 15.days.ago, to: 1.day.ago) }
    internal { [true, false].sample }
  end
end

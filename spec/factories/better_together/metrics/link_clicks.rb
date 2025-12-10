# frozen_string_literal: true

FactoryBot.define do
  factory :metrics_link_click, class: 'BetterTogether::Metrics::LinkClick' do
    url { 'https://example.com' }
    page_url { '/test-page' }
    locale { I18n.default_locale.to_s }
    clicked_at { Time.current }
    internal { false }
  end
end

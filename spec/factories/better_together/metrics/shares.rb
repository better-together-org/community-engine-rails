# frozen_string_literal: true

FactoryBot.define do
  factory :metrics_share, class: 'BetterTogether::Metrics::Share', aliases: [:share] do
    url { Faker::Internet.url(path: "/#{Faker::Internet.slug}") }
    platform { %w[email facebook bluesky linkedin pinterest reddit whatsapp].sample }
    platform_id { BetterTogether::Platform.find_by(host: true)&.id || association(:better_together_platform, :host).id }
    shared_at { Faker::Time.between(from: 15.days.ago, to: 1.day.ago) }
    locale { I18n.default_locale.to_s }
    logged_in { false }

    trait :with_community do
      association :shareable, factory: :community
    end
  end
end

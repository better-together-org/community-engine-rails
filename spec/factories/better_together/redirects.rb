# frozen_string_literal: true

FactoryBot.define do
  factory 'better_together/redirect',
          class: 'BetterTogether::Redirect',
          aliases: %i[better_together_redirect redirect] do
    association :platform, factory: :'better_together/platform'
    sequence(:from_path) { |n| "/old/page-#{n}.html" }
    to_path { '/en/new-page' }
    status { 301 }

    trait :gone do
      to_path { nil }
      status { 410 }
    end
  end
end

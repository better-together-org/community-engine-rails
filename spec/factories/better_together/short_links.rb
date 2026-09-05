# frozen_string_literal: true

FactoryBot.define do
  factory :better_together_short_link,
          class: 'BetterTogether::ShortLink' do
    id         { SecureRandom.uuid }
    code       { BetterTogether::ShortLink::CODE_ALPHABET.sample(BetterTogether::ShortLink::CODE_LENGTH).join }
    target_url { Faker::Internet.url(scheme: 'https') }
    status     { 'active' }
    expires_at { nil }

    before(:create) do |link|
      unless link.platform_id.present?
        link.platform = Current.platform ||
                        BetterTogether::Platform.find_by(host: true) ||
                        create(:better_together_platform)
      end
    end

    trait :inactive do
      status { 'inactive' }
    end

    trait :expired do
      status     { 'active' }
      expires_at { 1.day.ago }
    end
  end
end

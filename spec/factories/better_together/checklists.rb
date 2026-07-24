# frozen_string_literal: true

FactoryBot.define do
  factory :better_together_checklist, class: 'BetterTogether::Checklist' do
    id { SecureRandom.uuid }
    creator { nil }
    protected { false }
    privacy { 'private' }
    sequence(:title) { |n| "Test Checklist #{n}" }
    # :public — the base platform factory defaults to 'private', which would
    # make an overridden 'public'/'community' checklist privacy exceed its
    # platform's privacy ceiling (see PrivacyCeilingValidatable).
    association :platform, factory: %i[better_together_platform public]
  end
end

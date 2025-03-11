# frozen_string_literal: true

# spec/factories/platform_invitations.rb

FactoryBot.define do # rubocop:todo Metrics/BlockLength
  factory :better_together_platform_invitation,
          class: 'BetterTogether::PlatformInvitation',
          aliases: %i[platform_invitation] do
    id { SecureRandom.uuid }
    lock_version { 0 }
    invitee_email { Faker::Internet.email }
    status { 'pending' } # Adjust this based on valid statuses in your app
    locale { I18n.available_locales.sample.to_s }
    valid_from { Time.zone.now }
    valid_until { valid_from + 7.days } # Optional, set to one week from valid_from

    # Associations
    association :invitable, factory: :platform
    association :inviter, factory: :person # Assumes a factory for Person exists
    association :community_role, factory: :role # Assumes a factory for Role exists
    association :platform_role, factory: :role # Assumes a factory for Role exists
    invitee_id { nil } # Set to nil by default

    trait :expired do
      status { 'expired' }
      valid_until { 1.day.ago }
    end

    trait :accepted do
      status { 'accepted' }
      valid_until { nil } # Optional, no expiration
    end

    trait :greeting do
      greeting { '<p><b>Greeting message!</b></p>' }
    end
  end
end

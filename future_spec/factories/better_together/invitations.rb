# frozen_string_literal: true

FactoryBot.define do
  factory :better_together_invitation, class: BetterTogether::Invitation do
    id { Faker::Internet.uuid }
    inviter
    invitee
    status { %w[pending declined accepted].sample }
    valid_from { DateTime.now }
  end
end

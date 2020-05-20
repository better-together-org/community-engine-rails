
FactoryBot.define do
  factory :better_together_invitation, class: BetterTogether::Invitation do
    bt_id { Faker::Internet.uuid }
    inviter
    invitee
    status { %w(pending declined accepted).sample }
    valid_from { DateTime.now }
  end
end

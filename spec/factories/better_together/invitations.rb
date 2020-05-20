
FactoryBot.define do
  factory :better_together_invitation, class: BetterTogether::Invitation do
    inviter
    invitee
    status { %w(pending declined accepted).sample }
    valid_from { DateTime.now }
  end
end

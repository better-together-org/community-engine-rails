
FactoryBot.define do
  factory :better_together_community_invitation, class: BetterTogether::Community::Invitation do
    inviter
    invitee
    status { %w(pending declined accepted).sample }
    valid_from { DateTime.now }
  end
end

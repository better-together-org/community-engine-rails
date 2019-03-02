
FactoryBot.define do
  factory :better_together_core_invitation, class: BetterTogether::Core::Invitation do
    inviter
    invitee
    status { %w(pending declined accepted).sample }
    valid_from { DateTime.now }
  end
end

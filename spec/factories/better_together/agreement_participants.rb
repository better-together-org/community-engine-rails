# frozen_string_literal: true

FactoryBot.define do
  factory :better_together_agreement_participant, class: 'BetterTogether::AgreementParticipant' do
    association :agreement, factory: :better_together_agreement
    association :person, factory: :better_together_person
    group_identifier { nil }
  end
end

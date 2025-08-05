# frozen_string_literal: true

FactoryBot.define do
  factory 'better_together/agreement_term',
          class: 'BetterTogether::AgreementTerm',
          aliases: %i[better_together_agreement_term agreement_term] do
    id { SecureRandom.uuid }
    association :agreement, factory: :agreement
    content { Faker::Lorem.paragraph }
    protected { false }
  end
end

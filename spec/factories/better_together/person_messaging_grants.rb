# frozen_string_literal: true

FactoryBot.define do
  factory 'better_together/person_messaging_grant',
          class: 'BetterTogether::PersonMessagingGrant',
          aliases: %i[better_together_person_messaging_grant person_messaging_grant] do
    association :grantor, factory: :better_together_person
    association :grantee, factory: :better_together_person
  end
end

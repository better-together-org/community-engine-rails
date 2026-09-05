# frozen_string_literal: true

FactoryBot.define do
  factory :better_together_one_time_prekey,
          class: 'BetterTogether::OneTimePrekey',
          aliases: %i[one_time_prekey] do
    association :person, factory: :better_together_person
    sequence(:key_id) { |n| n }
    public_key { "base64encodedpublickey#{SecureRandom.hex(8)}==" }
    consumed { false }
  end
end

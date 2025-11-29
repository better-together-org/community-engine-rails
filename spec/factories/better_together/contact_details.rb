# frozen_string_literal: true

FactoryBot.define do
  factory :better_together_contact_detail, class: BetterTogether::ContactDetail, aliases: [:contact_detail] do
    association :contactable, factory: :person
  end
end

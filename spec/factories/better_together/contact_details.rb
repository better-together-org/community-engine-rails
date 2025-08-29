# frozen_string_literal: true

FactoryBot.define do
  factory :better_together_contact_detail, class: BetterTogether::ContactDetail, aliases: [:contact_detail] do
    # contactable association should be set by the caller
  end
end

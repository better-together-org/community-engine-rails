# frozen_string_literal: true

FactoryBot.define do
  factory :better_together_email_address, class: BetterTogether::EmailAddress, aliases: [:email_address] do
    email { Faker::Internet.unique.email }
    label { 'primary' }
    primary_flag { true }
    # contact_detail association should be set by the caller
  end
end

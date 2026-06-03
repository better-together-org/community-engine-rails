# frozen_string_literal: true

FactoryBot.define do
  factory :better_together_call_for_interest, class: 'BetterTogether::CallForInterest' do
    identifier { "call-for-interest-#{SecureRandom.hex(8)}" }
    name { "Call For Interest #{SecureRandom.hex(4)}" }
    description { 'Community members can express interest in this initiative.' }
    privacy { 'public' }
  end
end

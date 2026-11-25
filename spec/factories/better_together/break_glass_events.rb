# frozen_string_literal: true

FactoryBot.define do
  factory :better_together_break_glass_event, class: 'BetterTogether::BreakGlassEvent' do
    association :break_glass_grant, factory: :better_together_break_glass_grant
    actor { break_glass_grant.requested_by }
    platform { break_glass_grant.platform }
    event_type { 'requested' }
    detail { {} }
  end
end

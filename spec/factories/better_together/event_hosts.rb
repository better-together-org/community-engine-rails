# frozen_string_literal: true

FactoryBot.define do
  factory :better_together_event_host, class: 'BetterTogether::EventHost' do
    association :event, factory: :better_together_event
    association :host, factory: :better_together_community
  end
end

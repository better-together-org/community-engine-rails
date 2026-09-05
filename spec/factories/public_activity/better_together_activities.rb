# frozen_string_literal: true

FactoryBot.define do
  factory :public_activity_activity, class: 'BetterTogether::Activity' do
    association :trackable, factory: :better_together_page
    association :owner, factory: :better_together_person
    key { "#{trackable_type.demodulize.underscore}.create" }
    privacy { 'public' }
    parameters { {} }
  end
end

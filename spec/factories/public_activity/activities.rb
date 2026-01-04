# frozen_string_literal: true

FactoryBot.define do
  factory :activity, class: 'PublicActivity::Activity' do
    association :trackable, factory: :better_together_page
    association :owner, factory: :better_together_person
    key { "#{trackable_type.demodulize.underscore}.create" }
    privacy { 'public' }
    parameters { {} }

    trait :private do
      privacy { 'private' }
    end

    trait :for_page do
      association :trackable, factory: :better_together_page
    end

    trait :for_post do
      association :trackable, factory: :better_together_post
    end

    trait :for_event do
      association :trackable, factory: :better_together_event
    end
  end
end

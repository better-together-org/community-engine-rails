# frozen_string_literal: true

require 'faker'

# Authorable model specs
module BetterTogether
  FactoryBot.define do
    factory :better_together_authorable, class: Authorable do
      id { Faker::Internet.uuid }
      authorable
    end
  end
end

# frozen_string_literal: true

require 'faker'

# Author model specs
module BetterTogether
  FactoryBot.define do
    factory :better_together_author, class: Author do
      id { Faker::Internet.uuid }
      author
    end
  end
end

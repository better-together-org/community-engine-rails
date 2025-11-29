# frozen_string_literal: true

require 'faker'

module BetterTogether
  FactoryBot.define do
    factory(
      :better_together_role,
      class: Role,
      aliases: %i[role]
    ) do
      id { Faker::Internet.uuid }
      protected { false }
      name { Faker::Name.name }
      resource_type { Role::RESOURCE_CLASSES.sample }

      trait :platform_role do
        resource_type { 'BetterTogether::Platform' }
      end

      trait :community_role do
        resource_type { 'BetterTogether::Community' }
      end
    end
  end
end

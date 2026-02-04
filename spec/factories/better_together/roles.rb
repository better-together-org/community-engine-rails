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

      # Specific role identifier traits
      trait :platform_manager do
        identifier { 'platform_manager' }
        name { 'Platform Manager' }
        resource_type { 'BetterTogether::Platform' }
        protected { true }
      end

      trait :platform_analytics_viewer do
        identifier { 'platform_analytics_viewer' }
        name { 'Platform Analytics Viewer' }
        resource_type { 'BetterTogether::Platform' }
        protected { true }
      end

      trait :community_member do
        identifier { 'community_member' }
        name { 'Community Member' }
        resource_type { 'BetterTogether::Community' }
        protected { true }
      end

      trait :community_organizer do
        identifier { 'community_facilitator' }
        name { 'Community Facilitator' }
        resource_type { 'BetterTogether::Community' }
        protected { true }
      end

      trait :community_facilitator do
        identifier { 'community_facilitator' }
        name { 'Community Facilitator' }
        resource_type { 'BetterTogether::Community' }
        protected { true }
      end
    end
  end
end

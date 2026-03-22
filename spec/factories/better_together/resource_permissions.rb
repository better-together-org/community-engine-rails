# frozen_string_literal: true

# spec/factories/better_together/resource_permissions.rb

FactoryBot.define do
  factory :better_together_resource_permission,
          class: 'BetterTogether::ResourcePermission',
          aliases: %i[resource_permission] do
    identifier { "#{action}_#{target}_#{SecureRandom.hex(6)}" }
    action { BetterTogether::ResourcePermission::ACTIONS.sample }
    resource_type { BetterTogether::Resourceful::RESOURCE_CLASSES.sample }
    # Derive target from the resource_type (e.g., 'BetterTogether::Community' => 'community')
    target { resource_type.demodulize.underscore }
    # Position is validated unique per resource_type; use large random numbers for parallel safety
    position { rand(1_000_000..10_000_000) }
  end
end

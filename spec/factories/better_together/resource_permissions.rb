# frozen_string_literal: true

# spec/factories/better_together/resource_permissions.rb

FactoryBot.define do
  factory :better_together_resource_permission,
          class: 'BetterTogether::ResourcePermission',
          aliases: %i[resource_permission] do
    action { BetterTogether::ResourcePermission::ACTIONS.sample }
    resource_type { BetterTogether::Resourceful::RESOURCE_CLASSES.sample }
    # Derive target from the resource_type (e.g., 'BetterTogether::Community' => 'community')
    target { resource_type.demodulize.underscore }
    # Position is automatically assigned by the Positioned concern based on resource_type scope
  end
end

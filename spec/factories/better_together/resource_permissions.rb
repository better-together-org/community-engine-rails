# frozen_string_literal: true

# spec/factories/better_together/resource_permissions.rb

FactoryBot.define do
  factory :better_together_resource_permission,
          class: 'BetterTogether::ResourcePermission',
          aliases: %i[resource_permission] do
    action { "MyString" }
    resource_type { "MyString" }
  end
end

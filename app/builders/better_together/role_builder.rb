# frozen_string_literal: true

# app/builders/better_together/role_builder.rb

module BetterTogether
  # Base builder to automate creation of important built-in data types
  class RoleBuilder < Builder
    class << self
      def seed_data
        build_platform_roles
      end

      def build_platform_roles
        roles = platform_role_attrs

        ::BetterTogether::Role.create(roles)
      rescue => e
        e
      end

      # Clear existing data - Use with caution!
      def clear_existing
        ::BetterTogether::Role.delete_all
      end

      def platform_role_attrs
        [
          {
            protected: true,
            identifier: 'platform_super_administrator',
            resource_class: '::BetterTogether::Platform',
            name: 'Super Administrator',
            description: 'Ultimate authority over platform decisions, admin account management, and strategic direction.
               Full system access and ownership control.'
          }
        ]
      end
    end
  end
end

# frozen_string_literal: true

# app/builders/better_together/access_control_builder.rb

module BetterTogether
  # Plants the default roles, resource permissions and role-permission assignments for a platform.
  # The data lives in the seed packet at config/seeds/better_together/rbac; this class only chooses
  # the platform and applies the packet, so every platform gets its own copy of the default set.
  class AccessControlBuilder < Builder
    PACKET_PATH = BetterTogether::Engine.root.join('config/seeds/better_together/rbac')

    class << self
      def build(clear: false, platform: nil)
        PublicVisibilityGate.as_system do
          ActiveRecord::Base.transaction { clear_existing(platform:) } if clear
          seed_data(platform:)
        end
      end

      def seed_data(platform: nil)
        platform ||= default_platform
        report = Seeds::Plant.call(path: PACKET_PATH, platform:, apply: true)
        raise "RBAC seed packet failed: #{report[:errors].inspect}" if report[:errors].present?

        report
      end

      # Removes the platform's role data. Use with caution!
      def clear_existing(platform: nil)
        platform ||= default_platform
        roles = ::BetterTogether::Role.where(platform_id: platform.id)
        permissions = ::BetterTogether::ResourcePermission.where(platform_id: platform.id)
        ::BetterTogether::RoleResourcePermission.where(role_id: roles.select(:id)).delete_all
        roles.delete_all
        permissions.delete_all
      end

      private

      def default_platform
        Current.platform || ::BetterTogether::Platform.find_by(host: true) ||
          raise('A platform is required to seed roles and permissions')
      end
    end
  end
end

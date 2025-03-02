# frozen_string_literal: true

module BetterTogether
  # Concern that when included allows model to become a member of joinables via memberships
  module Member
    extend ActiveSupport::Concern

    included do # rubocop:todo Metrics/BlockLength
      class_attribute :joinable_role_associations, :joinable_membership_classes
      self.joinable_role_associations = []
      self.joinable_membership_classes = []

      def self.member(joinable_type:, member_type:, **membership_options) # rubocop:todo Metrics/MethodLength
        membership_class = "BetterTogether::#{member_type.camelize}#{joinable_type.camelize}Membership"
        membership_name = :"#{member_type}_#{joinable_type}_memberships"
        plural_joinable_type = joinable_type.to_s.pluralize
        joinable_roles_association = :"#{joinable_type}_roles"

        has_many membership_name,
                 foreign_key: :member_id,
                 class_name: membership_class,
                 **membership_options

        has_many :"member_#{plural_joinable_type}",
                 through: membership_name,
                 source: :joinable,
                 inverse_of: :"#{member_type}_members"

        has_many joinable_roles_association,
                 through: membership_name,
                 source: :role

        # Register the association name for role retrieval
        joinable_role_associations << joinable_roles_association
        joinable_membership_classes << membership_class
      end

      # Cache roles for the current instance
      def roles
        Rails.cache.fetch(cache_key_for(:roles), expires_in: 12.hours) do
          ::BetterTogether::Role.joins(:role_resource_permissions).where(
            id: self.class.joinable_role_associations.flat_map { |assoc| send(assoc).pluck(:id) }
          ).to_a
        end
      end

      # Cache role IDs for quick lookup
      def role_ids
        Rails.cache.fetch(cache_key_for(:role_ids), expires_in: 12.hours) do
          roles.pluck(:id)
        end
      end

      # Cache role-resource-permissions for the current instance
      def role_resource_permissions
        Rails.cache.fetch(cache_key_for(:role_resource_permissions), expires_in: 12.hours) do
          ::BetterTogether::RoleResourcePermission.includes(:resource_permission, role: [:string_translations])
                                                  .where(role_id: role_ids)
                                                  .order(::BetterTogether::Role.arel_table[:position].asc)
                                                  .to_a
        end
      end

      # Cache resource permissions for the current instance
      def resource_permissions
        Rails.cache.fetch(cache_key_for(:resource_permissions), expires_in: 12.hours) do
          ::BetterTogether::ResourcePermission.where(
            id: role_resource_permissions.pluck(:resource_permission_id)
          ).to_a
        end
      end

      # Permission check against cached resource permissions, with optional record
      def permitted_to?(permission_identifier, record = nil) # rubocop:todo Metrics/MethodLength
        Rails.cache.fetch(cache_key_for(:permitted_to, permission_identifier), expires_in: 12.hours) do
          # Cache permissions by identifier to avoid repeated lookups
          @permissions_by_identifier ||= resource_permissions.index_by(&:identifier)

          resource_permission = @permissions_by_identifier[permission_identifier]
          return false if resource_permission.nil?

          if record
            record_permission_granted?(resource_permission,
                                       record)
          else
            global_permission_granted?(resource_permission)
          end
        end
      end

      private

      # Global permission check
      def global_permission_granted?(resource_permission)
        role_resource_permissions.any? do |rrp|
          rrp.resource_permission_id == resource_permission.id
        end
      end

      # Record-specific permission check
      def record_permission_granted?(resource_permission, record)
        membership_class = membership_class_for(record)
        return false unless membership_class

        # Check if the member has a membership tied explicitly to the record
        memberships = membership_class.where(
          member: self,
          joinable_id: record.id
        ).includes(:role)

        memberships.any? do |membership|
          membership.role.role_resource_permissions.exists?(resource_permission_id: resource_permission.id)
        end
      end

      # Determine the membership class for the record's joinable type
      def membership_class_for(record)
        joinable_type = record.class.joinable_type
        membership_class_name = self.class.joinable_membership_classes.find do |assoc|
          assoc.to_s.include?(joinable_type.capitalize)
        end

        membership_class_name&.to_s&.classify&.constantize # rubocop:todo Style/SafeNavigationChainLength
      end

      # Generate a unique cache key for each instance and method
      def cache_key_for(method, identifier = nil)
        base_key = "#{I18n.locale}/better_together/member/#{self.class.name}/#{id}/#{cache_version}/#{method}"
        identifier ? "#{base_key}/#{identifier}" : base_key
      end
    end
  end
end

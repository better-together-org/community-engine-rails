# frozen_string_literal: true

module BetterTogether
  # Concern that when included allows model to become a member of joinables via memberships
  module Member
    extend ActiveSupport::Concern

    included do
      class_attribute :joinable_role_associations
      self.joinable_role_associations = []

      def self.member(joinable_type:, member_type:, **membership_options)
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
      end

      # Cache roles for the current instance
      def roles
        @roles ||= ::BetterTogether::Role.joins(:role_resource_permissions).where(
          id: self.class.joinable_role_associations.flat_map { |assoc| send(assoc).pluck(:id) }
        )
      end

      # Cache role IDs for quick lookup
      def role_ids
        @role_ids ||= roles.pluck(:id)
      end

      # Cache role-resource-permissions for the current instance
      def role_resource_permissions
        @role_resource_permissions ||= ::BetterTogether::RoleResourcePermission.joins(:role, :resource_permission)
                                                                               .where(role_id: role_ids)
                                                                               .order(::BetterTogether::Role.arel_table[:position].asc)
      end

      # Cache resource permissions for the current instance
      def resource_permissions
        @resource_permissions ||= ::BetterTogether::ResourcePermission.where(
          id: role_resource_permissions.pluck(:resource_permission_id)
        )
      end

      # Permission check against cached resource permissions
      def permitted_to?(permission_identifier)
        # Cache permissions by identifier to avoid repeated lookups
        @permissions_by_identifier ||= resource_permissions.index_by(&:identifier)

        resource_permission = @permissions_by_identifier[permission_identifier]

        raise StandardError, "Permission not found using identifier #{permission_identifier}" if resource_permission.nil?

        role_resource_permissions.any? do |rrp|
          rrp.resource_permission_id == resource_permission.id
        end
      end
    end
  end
end

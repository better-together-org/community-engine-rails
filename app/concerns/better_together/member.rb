# frozen_string_literal: true

module BetterTogether
  # Concern that when included allows model to become a member of joinables via memberships
  module Member
    extend ActiveSupport::Concern

    included do # rubocop:todo Metrics/BlockLength
      class_attribute :joinable_role_associations
      self.joinable_role_associations = []

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
      end

      def role_ids
        roles.pluck(:id)
      end

      # Fetch all unique roles across all membership types
      def roles
        return @roles if @roles

        association_role_ids = []

        self.class.joinable_role_associations.each do |association|
          association_role_ids.concat(send(association).pluck(:id))
        end

        @roles = ::BetterTogether::Role.where(id: association_role_ids)

        @roles
      end

      def role_resource_permissions
        @role_resource_permissions ||=
          ::BetterTogether::RoleResourcePermission.joins(:role, :resource_permission)
                                                  .where(role_id: role_ids)
                                                  .order(::BetterTogether::Role.arel_table[:position].asc)
      end

      def resource_permissions
        # rubocop:todo Layout/LineLength
        @resource_permissions ||= ::BetterTogether::ResourcePermission.where(id: role_resource_permissions.pluck(:resource_permission_id))
        # rubocop:enable Layout/LineLength
      end

      def permitted_to?(permission_identifier)
        resource_permission =
          ::BetterTogether::ResourcePermission.find_by(identifier: permission_identifier)

        raise StandardError, "Permission not found using identifer #{permission_identifier}" if resource_permission.nil?

        resource_permissions.find_by(id: resource_permission.id).present?
      end
    end
  end
end

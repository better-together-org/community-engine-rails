# frozen_string_literal: true

module BetterTogether
  # Used to determine the user's access to features and data
  class Role < ApplicationRecord
    include Identifier
    include Positioned
    include Protected
    include Resourceful

    has_many :role_resource_permissions, class_name: 'BetterTogether::RoleResourcePermission', dependent: :destroy
    has_many :resource_permissions, through: :role_resource_permissions

    slugged :identifier, dependent: :delete_all

    translates :name, type: :string
    translates :description, type: :text

    validates :name,
              presence: true

    scope :positioned, -> { order(:resource_type, :position) }
    after_commit :expire_affected_member_permission_caches

    def assign_resource_permissions(permission_identifiers, save_record: true, sync: false)
      permissions = ::BetterTogether::ResourcePermission.where(identifier: permission_identifiers)
      synchronize_resource_permissions!(permissions) if sync

      # Avoid duplicate join records when called multiple times
      new_permissions = permissions.where.not(id: resource_permissions.select(:id))
      resource_permissions << new_permissions if new_permissions.any?

      save if save_record
    end

    def to_s
      name
    end

    private

    def expire_affected_member_permission_caches
      BetterTogether::Person.expire_permission_cache_for_ids(affected_member_ids)
    end

    def affected_member_ids
      platform_member_ids = BetterTogether::PersonPlatformMembership.where(role_id: id).pluck(:member_id)
      community_member_ids = BetterTogether::PersonCommunityMembership.where(role_id: id).pluck(:member_id)

      (platform_member_ids + community_member_ids).uniq
    end

    def synchronize_resource_permissions!(permissions)
      resource_types = permissions.distinct.pluck(:resource_type)
      return if resource_types.empty?

      stale_permission_ids = resource_permissions
                             .where(resource_type: resource_types)
                             .where.not(id: permissions.select(:id))
                             .pluck(:id)
      return if stale_permission_ids.empty?

      role_resource_permissions.where(resource_permission_id: stale_permission_ids).delete_all
    end

    def position_scope
      :resource_type
    end
  end
end

# frozen_string_literal: true

module BetterTogether
  # Allows for assigning permitted actions to resources
  class ResourcePermission < ApplicationRecord
    ACTIONS = %w[create read update delete list manage view download].freeze

    include Identifier
    include Positioned
    include Protected
    include Resourceful

    has_many :role_resource_permissions, class_name: 'BetterTogether::RoleResourcePermission', dependent: :destroy
    has_many :roles, through: :role_resource_permissions

    slugged :identifier, dependent: :delete_all

    validates :action, inclusion: { in: ACTIONS }
    validates :position, uniqueness: { scope: :resource_type }

    scope :positioned, -> { order(:resource_type, :position) }
    after_commit :expire_affected_member_permission_caches

    def position_scope
      :resource_type
    end

    def to_s
      identifier
    end

    private

    def expire_affected_member_permission_caches
      affected_role_ids = role_resource_permissions.pluck(:role_id)
      return if affected_role_ids.empty?

      platform_member_ids = BetterTogether::PersonPlatformMembership.where(role_id: affected_role_ids).pluck(:member_id)
      community_member_ids = BetterTogether::PersonCommunityMembership.where(role_id: affected_role_ids).pluck(:member_id)

      BetterTogether::Person.expire_permission_cache_for_ids(platform_member_ids + community_member_ids)
    end
  end
end

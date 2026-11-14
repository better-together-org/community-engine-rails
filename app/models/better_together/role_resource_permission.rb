# frozen_string_literal: true

module BetterTogether
  # Assigns resource permisisons to roles
  class RoleResourcePermission < PlatformRecord
    belongs_to :role, class_name: 'BetterTogether::Role'
    belongs_to :resource_permission, class_name: 'BetterTogether::ResourcePermission'

    validates :role, presence: true
    validates :resource_permission, presence: true
    validates :role_id, uniqueness: { scope: :resource_permission_id }
    after_commit :expire_affected_member_permission_caches

    def to_s
      "#{role.name} - #{resource_permission.identifier}"
    end

    private

    def expire_affected_member_permission_caches
      return unless role.present?

      BetterTogether::Person.expire_permission_cache_for_ids(role.send(:affected_member_ids))
    end
  end
end

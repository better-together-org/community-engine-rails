# frozen_string_literal: true

module BetterTogether
  # Concern that when included allows model to be joined via memberships
  module Membership
    extend ActiveSupport::Concern

    included do
      def self.membership(member_class:, joinable_class:)
        belongs_to :joinable,
                   class_name: joinable_class,
                   autosave: true
        belongs_to :member,
                   class_name: member_class,
                   touch: true
        belongs_to :role, -> { where(resource_type: joinable_class) }

        validates :member, :role, :joinable, presence: true
        validates :role_id, uniqueness: {
          scope: %i[joinable_id member_id]
        }
        validate :role_belongs_to_joinable_platform
      end

      def self.extra_permitted_attributes
        super + %i[member_id joinable_id role_id]
      end
    end

    private

    # Roles are per platform, so a membership can only hold a role defined on its own platform.
    def role_belongs_to_joinable_platform
      return if role.blank? || joinable.blank? || role.platform_id.blank?

      owner_id = joinable_platform_id
      errors.add(:role, :invalid) if owner_id.present? && owner_id != role.platform_id
    end

    def joinable_platform_id
      joinable.is_a?(BetterTogether::Platform) ? joinable.id : joinable.try(:platform_id)
    end
  end
end

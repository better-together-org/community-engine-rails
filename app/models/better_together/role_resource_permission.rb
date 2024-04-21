# frozen_string_literal: true

module BetterTogether
  class RoleResourcePermission < ApplicationRecord
    belongs_to :role, class_name: 'BetterTogether::Role'
    belongs_to :resource_permission, class_name: 'BetterTogether::ResourcePermission'

    validates :role, presence: true
    validates :resource_permission, presence: true
    validates :role_id, uniqueness: { scope: :resource_permission_id }

    def to_s
      "#{role.name} - #{resource_permission.identifier}"
    end
  end
end

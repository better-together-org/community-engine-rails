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

    translates :name
    translates :description, type: :text

    validates :name,
              presence: true

    scope :positioned, -> { order(:resource_type, :position) }

    def assign_resource_permissions(permission_identifiers, save_record: true)
      permissions = ::BetterTogether::ResourcePermission.where(identifier: permission_identifiers)
      resource_permissions << permissions

      save if save_record
    end

    def position_scope
      :resource_type
    end

    def to_s
      name
    end
  end
end

# frozen_string_literal: true

module BetterTogether
  # Concern that when included allows model to be joined via memberships
  module Joinable
    extend ActiveSupport::Concern

    included do
      class_attribute :member_role_associations
      self.member_role_associations = []

      def self.joinable(joinable_type:, member_type:, **membership_options) # rubocop:todo Metrics/MethodLength
        membership_class = "BetterTogether::#{member_type.camelize}#{joinable_type.camelize}Membership"
        membership_name = :"#{member_type}_#{joinable_type}_memberships"

        plural_joinable_type = joinable_type.to_s.pluralize
        member_roles_association = :"#{member_type}_roles"

        has_many membership_name,
                 foreign_key: :joinable_id,
                 class_name: membership_class,
                 **membership_options

        has_many :"#{member_type}_members",
                 through: membership_name,
                 source: :member,
                 inverse_of: :"member_#{plural_joinable_type}"

        has_many member_roles_association,
                 through: membership_name,
                 source: :role

        # Register the association name for role retrieval
        member_role_associations << member_roles_association
      end
    end
  end
end

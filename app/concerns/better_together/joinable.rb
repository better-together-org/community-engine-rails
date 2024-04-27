# frozen_string_literal: true

module BetterTogether
  # Concern that when included allows model to be joined via memberships
  module Joinable
    extend ActiveSupport::Concern

    included do
      def self.joinable(joinable_type:, member_type:, **options)
        options = {
          foreign_key: :joinable_id,
          class_name: "BetterTogether::#{member_type.camelize}#{joinable_type.camelize}Membership",
          **options
        }

        membership_name = :"#{member_type}_#{joinable_type}_memberships"

        plural_member_type = member_type.to_s.pluralize

        has_many membership_name, **options

        has_many :"#{member_type}_members",
                 through: membership_name,
                 source: :member,
                 inverse_of: :"member_#{joinable_type.to_s.pluralize}"

        has_many :"#{member_type}_roles",
                 through: membership_name,
                 source: :role
      end
    end
  end
end

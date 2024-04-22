# frozen_string_literal: true

module BetterTogether
  # Concern that when included allows model to become a member of joinables via memberships
  module Member
    extend ActiveSupport::Concern

    included do

      def self.member(joinable_type:, member_type:, **options)
        options = {
          foreign_key: :member_id,
          class_name: "BetterTogether::#{member_type.camelize}#{joinable_type.camelize}Membership",
          **options
        }

        membership_name = "#{member_type}_#{joinable_type}_memberships".to_sym
        plural_joinable_type = joinable_type.to_s.pluralize

        has_many membership_name, **options

        has_many "member_#{plural_joinable_type}".to_sym,
                 through: membership_name,
                 source: :joinable,
                 inverse_of: "#{member_type}_members".to_sym

        has_many "#{joinable_type}_roles".to_sym,
                 through: membership_name,
                 source: :role
      end
    end
  end
end

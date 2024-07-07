# frozen_string_literal: true

module BetterTogether
  # Concern that when included allows model to be joined via memberships
  module Membership
    extend ActiveSupport::Concern

    included do
      def self.membership(member_class:, joinable_class:)
        belongs_to :joinable,
                   class_name: joinable_class
        belongs_to :member,
                   class_name: member_class
        belongs_to :role,
                   -> { where(resource_type: joinable_class) }

        validates :role, uniqueness: {
          scope: %i[joinable_id member_id]
        }
      end
    end
  end
end

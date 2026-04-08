# frozen_string_literal: true

module BetterTogether
  # Concern that when included allows model to be joined via memberships
  module Joinable
    extend ActiveSupport::Concern

    ACCESS_MODES = {
      open: :open,
      request: :request,
      invitation: :invitation
    }.freeze

    included do
      class_attribute :member_role_associations, :joinable_type, :membership_class
      self.member_role_associations = []

      def self.joinable(joinable_type:, member_type:, **membership_options) # rubocop:todo Metrics/MethodLength
        self.joinable_type = joinable_type

        membership_class_name = "BetterTogether::#{member_type.camelize}#{joinable_type.camelize}Membership"
        self.membership_class = membership_class_name.constantize

        membership_name = :"#{member_type}_#{joinable_type}_memberships"

        plural_joinable_type = joinable_type.to_s.pluralize
        member_roles_association = :"#{member_type}_roles"

        has_many membership_name,
                 foreign_key: :joinable_id,
                 class_name: membership_class_name,
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

    def access_mode
      return ACCESS_MODES[:invitation] if invitation_required_for_access?
      return ACCESS_MODES[:request] if membership_requests_enabled?

      ACCESS_MODES[:open]
    end

    def invitation_required_for_access?
      respond_to?(:requires_invitation?) && requires_invitation?
    end

    def membership_requests_enabled?
      return false unless has_attribute?(:allow_membership_requests)

      ActiveModel::Type::Boolean.new.cast(self[:allow_membership_requests])
    end

    def allows_direct_join?
      access_mode == ACCESS_MODES[:open]
    end

    def request_to_join_only?
      access_mode == ACCESS_MODES[:request]
    end

    def invitation_only?
      access_mode == ACCESS_MODES[:invitation]
    end

    def default_member_role_identifier
      "#{self.class.joinable_type}_member"
    end

    def default_member_role
      BetterTogether::Role.find_by(
        resource_type: self.class.name,
        identifier: default_member_role_identifier
      )
    end

    def supports_self_service_membership?
      default_member_role.present? && !invitation_only?
    end

    def self_service_membership_status
      allows_direct_join? ? 'active' : 'pending'
    end
  end
end

# frozen_string_literal: true

module BetterTogether
  module Api
    module V1
      # JSONAPI resource for Invitation
      # Exposes invitations the current user can manage
      class InvitationResource < ::BetterTogether::Api::ApplicationResource
        model_name '::BetterTogether::Invitation'

        # Attributes
        attributes :status, :locale, :invitee_email
        attribute :invitation_type
        attribute :valid_from
        attribute :valid_until
        attribute :accepted_at
        attribute :created_at

        # Relationships
        has_one :inviter, class_name: 'Person', foreign_key: :inviter_id
        has_one :invitee, class_name: 'Person', foreign_key: :invitee_id
        has_one :role

        # Filters
        filter :status
        filter :invitable_type

        # Virtual attribute
        def invitation_type
          @model.invitation_type.to_s
        end

        # Restrict creatable fields
        def self.creatable_fields(_context)
          %i[invitee_email locale role]
        end

        # Restrict updatable fields
        def self.updatable_fields(_context)
          %i[status]
        end

        # Override records to handle abstract InvitationPolicy::Scope
        # The base scope raises NotImplementedError for non-platform-managers
        def self.records(options = {})
          context = options[:context]
          user = context[:current_user]
          context[:policy_used]&.call

          scope = BetterTogether::Invitation.all
          return scope.none unless user.present?

          person = user.person
          return scope.all if person&.permitted_to?('manage_platform')

          # Regular users see invitations they sent or received
          scope.where(inviter: person).or(scope.where(invitee: person))
        end
      end
    end
  end
end

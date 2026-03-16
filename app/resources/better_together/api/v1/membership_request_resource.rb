# frozen_string_literal: true

module BetterTogether
  module Api
    module V1
      # JSONAPI resource for Joatu::MembershipRequest.
      # Extends the base JoatuRequestResource with membership-specific attributes.
      class MembershipRequestResource < JoatuRequestResource
        model_name '::BetterTogether::Joatu::MembershipRequest'

        attributes :requestor_name, :requestor_email, :referral_source,
                   :target_type, :target_id, :description

        # Assign creator from the JWT-authenticated user before attribute
        # assignment and before validation run, so unauthenticated? returns the
        # correct answer when the request email validation fires.
        def self.create(context)
          resource = super
          resource._model.creator = context[:current_user]&.person
          resource
        end

        # ActionText returns an ActionText::RichText object; serialize as plain text for JSON consumers.
        def description
          @model.description.to_plain_text
        end

        def description=(value)
          @model.description = value
        end

        def self.creatable_fields(_context)
          %i[name requestor_name requestor_email referral_source target_type target_id description]
        end

        def self.updatable_fields(_context)
          %i[requestor_name referral_source status]
        end
      end
    end
  end
end

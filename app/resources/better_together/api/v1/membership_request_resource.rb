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

        # Assign creator from the JWT-authenticated user before attribute assignment.
        # Name is auto-generated server-side via the model's before_validation callback.
        def self.create(context)
          resource = super
          resource._model.creator = context[:current_user]&.person
          resource
        end

        # Bypass pundit scope for unauthenticated requests so the post-create
        # response can locate the newly created record. All read/destroy actions
        # require authentication (via authenticate_api_user!), so unauthenticated
        # callers can only ever reach the :create action.
        def self.records(options = {})
          return _model_class.all if options.dig(:context, :current_user).nil?

          super
        end

        # ActionText returns an ActionText::RichText object; serialize as plain text for JSON consumers.
        def description
          @model.description&.to_plain_text.to_s
        end

        def description=(value)
          @model.description = value
        end

        def self.creatable_fields(_context)
          %i[requestor_name requestor_email referral_source target_type target_id description]
        end

        def self.updatable_fields(_context)
          %i[requestor_name referral_source status]
        end
      end
    end
  end
end

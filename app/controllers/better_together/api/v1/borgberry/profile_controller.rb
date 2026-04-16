# frozen_string_literal: true

module BetterTogether
  module Api
    module V1
      module Borgberry
        # Returns the authenticated person's borgberry identity profile.
        #
        # GET /api/v1/borgberry/profile
        #
        # Returns:
        #   200 { borgberry_did: "did:key:z6Mk...", person_id: "uuid" }
        #   401 — unauthenticated
        #   422 { error: "borgberry_did not set — has this account been enrolled?" }
        #         — authenticated but DID not yet assigned
        #
        # Used by `borgberry did show` to fetch and cache this node's DID.
        # Requires standard API authentication (JWT or OAuth2 bearer token).
        class ProfileController < BetterTogether::Api::ApplicationController
          def show
            person = current_person
            return head :unauthorized unless person

            did = person.borgberry_did
            if did.blank?
              return render json: { error: 'borgberry_did not set — has this account been enrolled?' },
                            status: :unprocessable_entity
            end

            render json: { borgberry_did: did, person_id: person.id }, status: :ok
          end
        end
      end
    end
  end
end

# frozen_string_literal: true

module BetterTogether
  module Api
    module V1
      # JSONAPI resource controller for conversations
      # Conversations are scoped to the current user's participation
      class ConversationsController < BetterTogether::Api::ApplicationController
        # GET /api/v1/conversations
        # Returns only conversations the authenticated user participates in
        def index
          super
        end

        # GET /api/v1/conversations/:id
        # Requires the user to be a participant
        def show
          super
        end

        # POST /api/v1/conversations
        # Creates a new conversation with participants
        # Current user is automatically added as participant
        def create
          super
        end

        # PATCH/PUT /api/v1/conversations/:id
        # Only the creator can update title
        def update
          super
        end

        # GET /api/v1/conversations/:id/participant_prekey_bundles
        # Returns prekey bundles for all participants in a conversation.
        # Gated to conversation members only.
        # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
        def participant_prekey_bundles
          @policy_used = true  # satisfy Pundit::ResourceController#enforce_policy_use
          conversation = BetterTogether::Conversation.find(params[:id])
          authorize conversation, :show?  # consistent Pundit check for participant membership

          bundles = conversation.participants.map do |person|
            next nil unless person.identity_key_public.present?

            one_time_prekey = consume_one_time_prekey_for(person)
            {
              person_id: person.id,
              registration_id: person.registration_id,
              identity_key: person.identity_key_public,
              signed_prekey: {
                id: person.signed_prekey_id,
                public_key: person.signed_prekey_public,
                signature: person.signed_prekey_sig
              },
              one_time_prekey: if one_time_prekey
                                 {
                                   id: one_time_prekey.key_id,
                                   public_key: one_time_prekey.public_key
                                 }
                               end
            }
          end.compact

          render json: { data: bundles }
        rescue Pundit::NotAuthorizedError, ActiveRecord::RecordNotFound
          render json: { error: 'Not found' }, status: :not_found
        end
        # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

        private

        def consume_one_time_prekey_for(person)
          BetterTogether::OneTimePrekey.transaction do
            prekey = person.one_time_prekeys.unconsumed.lock.first
            prekey&.update!(consumed: true)
            prekey
          end
        end
      end
    end
  end
end

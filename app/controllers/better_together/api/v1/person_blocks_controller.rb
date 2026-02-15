# frozen_string_literal: true

module BetterTogether
  module Api
    module V1
      # JSONAPI resource controller for person blocks
      # Allows users to manage their blocked people list
      class PersonBlocksController < BetterTogether::Api::ApplicationController
        # POST /api/v1/person_blocks
        # Custom create action that sets blocker before Pundit authorization
        def create # rubocop:disable Metrics/MethodLength
          blocked_id = params.dig(:data, :attributes, :blocked_id)
          blocked = BetterTogether::Person.find_by(id: blocked_id)

          block = BetterTogether::PersonBlock.new(
            blocker: current_user&.person,
            blocked: blocked
          )

          authorize block
          @policy_used = true

          if block.save
            render json: serialize_person_block(block), status: :created
          else
            render json: { errors: block.errors.full_messages.map { |m| { detail: m } } },
                   status: :unprocessable_entity
          end
        end

        # GET /api/v1/person_blocks
        # Scoped to current user's blocks via PersonBlockPolicy::Scope
        def index
          super
        end

        # GET /api/v1/person_blocks/:id
        # Only visible to the blocker
        def show
          super
        end

        # DELETE /api/v1/person_blocks/:id
        # Only the blocker can remove a block
        def destroy
          super
        end

        private

        def serialize_person_block(block)
          {
            data: {
              type: 'person_blocks',
              id: block.id,
              attributes: {
                blocked_id: block.blocked_id,
                created_at: block.created_at&.iso8601,
                updated_at: block.updated_at&.iso8601
              },
              relationships: {
                blocker: { data: { type: 'people', id: block.blocker_id } },
                blocked: { data: { type: 'people', id: block.blocked_id } }
              }
            }
          }
        end
      end
    end
  end
end

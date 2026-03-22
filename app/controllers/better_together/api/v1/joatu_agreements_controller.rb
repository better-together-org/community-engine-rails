# frozen_string_literal: true

module BetterTogether
  module Api
    module V1
      # JSONAPI resource controller for Joatu agreements
      # Includes custom accept/reject actions
      class JoatuAgreementsController < BetterTogether::Api::ApplicationController
        def index
          super
        end

        def show
          super
        end

        def create
          super
        end

        def update
          super
        end

        # POST /api/v1/joatu_agreements/:id/accept
        def accept
          transition_agreement(:accept)
        end

        # POST /api/v1/joatu_agreements/:id/reject
        def reject
          transition_agreement(:reject)
        end

        private

        def transition_agreement(action)
          agreement = BetterTogether::Joatu::Agreement.find(params[:id])
          authorize agreement, :"#{action}?"
          @policy_used = true

          agreement.public_send(:"#{action}!")
          render json: serialize_agreement(agreement), status: :ok
        rescue ActiveRecord::RecordInvalid => e
          render json: { errors: [{ detail: e.message }] }, status: :unprocessable_entity
        end

        def serialize_agreement(agreement)
          {
            data: {
              id: agreement.id,
              type: 'joatu_agreements',
              attributes: { status: agreement.status, terms: agreement.terms, value: agreement.value },
              relationships: {
                offer: { data: { type: 'joatu_offers', id: agreement.offer_id } },
                request: { data: { type: 'joatu_requests', id: agreement.request_id } }
              }
            }
          }
        end
      end
    end
  end
end

# frozen_string_literal: true

module BetterTogether
  module Api
    module V1
      # Provides authenticated deletion-request endpoints outside JSONAPI resource dispatch.
      class PersonDeletionRequestsController < BetterTogether::Api::ApplicationController
        skip_after_action :verify_authorized, raise: false
        skip_after_action :verify_policy_scoped, raise: false
        skip_after_action :enforce_policy_use, raise: false

        before_action :require_person!
        before_action :set_request, only: :destroy

        def index
          render json: {
            data: current_user.person.person_deletion_requests.latest_first.map { |request| serialize_request(request) }
          }
        end

        def create
          deletion_request = current_user.person.person_deletion_requests.create!(
            requested_at: Time.current,
            requested_reason: requested_reason
          )
          render json: { data: serialize_request(deletion_request) }, status: :created
        rescue ActiveRecord::RecordInvalid => e
          render json: { errors: e.record.errors.full_messages.map { |message| { detail: message } } },
                 status: :unprocessable_entity
        end

        def destroy
          @request.cancel!
          render json: { data: serialize_request(@request) }, status: :ok
        end

        private

        def require_person!
          return if current_user&.person

          render json: { error: 'Authentication required' }, status: :unauthorized
        end

        def set_request
          @request = current_user.person.person_deletion_requests.active.find(params[:id])
        end

        def requested_reason
          params[:requested_reason] || params.dig(:data, :attributes, :requested_reason)
        end

        def serialize_request(request)
          {
            id: request.id,
            type: 'person_deletion_requests',
            attributes: {
              status: request.status,
              requested_reason: request.requested_reason,
              requested_at: request.requested_at&.iso8601,
              resolved_at: request.resolved_at&.iso8601,
              reviewer_notes: request.reviewer_notes
            }
          }
        end
      end
    end
  end
end

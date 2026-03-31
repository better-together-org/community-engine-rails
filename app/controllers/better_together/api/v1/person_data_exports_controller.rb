# frozen_string_literal: true

module BetterTogether
  module Api
    module V1
      # Provides authenticated account-data export endpoints outside JSONAPI resource dispatch.
      class PersonDataExportsController < BetterTogether::Api::ApplicationController
        skip_after_action :verify_authorized, raise: false
        skip_after_action :verify_policy_scoped, raise: false
        skip_after_action :enforce_policy_use, raise: false

        before_action :require_person!
        before_action :set_export, only: :show

        def index
          render json: {
            data: current_user.person.person_data_exports.latest_first.map { |export| serialize_export(export) }
          }
        end

        def create
          export = current_user.person.person_data_exports.create!(requested_at: Time.current, format: 'json')
          render json: { data: serialize_export(export) }, status: :created
        end

        def show
          render json: { data: serialize_export(@export) }
        end

        private

        def require_person!
          return if current_user&.person

          render json: { error: 'Authentication required' }, status: :unauthorized
        end

        def set_export
          @export = current_user.person.person_data_exports.find(params[:id])
        end

        def serialize_export(export)
          {
            id: export.id,
            type: 'person_data_exports',
            attributes: {
              status: export.status,
              format: export.format,
              requested_at: export.requested_at&.iso8601,
              started_at: export.started_at&.iso8601,
              completed_at: export.completed_at&.iso8601,
              error_message: export.error_message,
              download_url: export_download_url(export)
            }
          }
        end

        def export_download_url(export)
          return unless export.completed? && export.export_file.attached?

          BetterTogether::Engine.routes.url_helpers.person_data_export_path(
            export,
            locale: I18n.default_locale
          )
        end
      end
    end
  end
end

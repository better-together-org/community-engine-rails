# frozen_string_literal: true

module BetterTogether
  module Api
    module Auth
      # JSONAPI resource for user sessions
      class SessionsController < BetterTogether::Users::SessionsController
        respond_to :json

        skip_before_action :check_platform_privacy, raise: false

        protected

        # Return JWT token and user info on successful authentication
        def respond_with(resource, _opts = {}) # rubocop:todo Metrics/AbcSize, Metrics/MethodLength
          token = request.env['warden-jwt_auth.token']

          render json: {
            data: {
              type: 'sessions',
              id: resource.id,
              attributes: {
                email: resource.email,
                token: token,
                confirmed: resource.confirmed_at.present?
              },
              relationships: {
                person: {
                  data: resource.person ? { type: 'people', id: resource.person.id } : nil
                }
              }
            },
            included: if resource.person
                        [
                          {
                            type: 'people',
                            id: resource.person.id,
                            attributes: {
                              name: resource.person.name,
                              identifier: resource.person.identifier,
                              privacy: resource.person.privacy,
                              locale: resource.person.locale,
                              time_zone: resource.person.time_zone
                            }
                          }
                        ]
                      else
                        []
                      end
          }
        end

        def respond_to_on_destroy
          render json: {
            message: 'Logged out successfully'
          }, status: :ok
        end

        def after_sign_in_path_for(_resource); end
      end
    end
  end
end

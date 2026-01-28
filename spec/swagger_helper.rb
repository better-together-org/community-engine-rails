# frozen_string_literal: true

require 'rails_helper'

RSpec.configure do |config|
  # Specify a root folder where Swagger JSON files are generated
  # NOTE: If you're using the rswag-api to serve API descriptions, you'll need
  # to ensure that it's configured to serve Swagger from the same folder
  config.swagger_root = BetterTogether::Engine.root.join('swagger').to_s

  # Define one or more Swagger documents and provide global metadata for each one
  # When you run the 'rswag:specs:swaggerize' rake task, the complete Swagger will
  # be generated at the provided relative path under swagger_root
  # By default, the operations defined in spec files are added to the first
  # document below. You can override this behavior by adding a swagger_doc tag to the
  # the root example_group in your specs, e.g. describe '...', swagger_doc: 'v2/swagger.json'
  config.swagger_docs = {
    'v1/swagger.yaml' => {
      openapi: '3.0.1',
      info: {
        title: 'Community Engine API',
        version: 'v1',
        description: <<~DESC
          Better Together Community Engine REST API

          ## Authentication

          Most endpoints require JWT authentication via Bearer token in the Authorization header.
          See the Authentication section for how to obtain tokens via sign-in.
        DESC
      },
      paths: {},
      servers: [
        # Default server using configured base URL
        {
          url: BetterTogether.base_url,
          description: 'Platform server'
        },
        # Include localhost only in development
        (if Rails.env.development?
           {
             url: 'http://localhost:3000',
             description: 'Local development server'
           }
         end)
      ].compact,
      components: {
        schemas: {
          ValidationErrors: {
            type: :object,
            description: 'Standard validation error response format',
            properties: {
              errors: {
                type: :array,
                items: { type: :string },
                description: 'Array of human-readable error messages',
                example: ["Email can't be blank", 'Password is too short']
              }
            }
          },
          User: {
            type: :object,
            description: 'User account with authentication credentials',
            properties: {
              id: {
                type: :string,
                format: :uuid,
                description: 'Unique user identifier'
              },
              email: {
                type: :string,
                format: :email,
                description: 'User email address'
              },
              created_at: {
                type: :string,
                format: :'date-time',
                description: 'Account creation timestamp'
              }
            },
            required: %w[id email created_at]
          }
        }
      }
    }
  }

  # Specify the format of the output Swagger file when running 'rswag:specs:swaggerize'.
  # The swagger_docs configuration option has the filename including format in
  # the key, this may want to be changed to avoid putting yaml in json files.
  # Defaults to json. Accepts ':json' and ':yaml'.
  config.swagger_format = :yaml
end

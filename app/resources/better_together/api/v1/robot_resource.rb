# frozen_string_literal: true

module BetterTogether
  module Api
    module V1
      # JSONAPI resource for BetterTogether::Robot
      class RobotResource < ::BetterTogether::Api::ApplicationResource
        model_name '::BetterTogether::Robot'

        attributes :name, :identifier, :provider, :robot_type, :active,
                   :default_model, :default_embedding_model, :system_prompt, :settings,
                   :platform_id

        filter :identifier
        filter :platform_id
        filter :active

        def self.creatable_fields(_context)
          %i[
            name identifier provider robot_type active
            default_model default_embedding_model system_prompt settings
            platform_id
          ]
        end

        def self.updatable_fields(context)
          creatable_fields(context)
        end
      end
    end
  end
end

# frozen_string_literal: true

module BetterTogether
  module Api
    module V1
      # JSONAPI resource for governed contributions / authorships
      class AuthorshipResource < ::BetterTogether::Api::ApplicationResource
        model_name '::BetterTogether::Authorship'

        attributes :author_id, :author_type, :authorable_id, :authorable_type,
                   :role, :contribution_type, :position

        has_one :creator, class_name: 'Person'

        filter :author_id
        filter :author_type
        filter :authorable_id
        filter :authorable_type
        filter :role

        def self.creatable_fields(_context)
          %i[
            author_id author_type authorable_id authorable_type
            role contribution_type position
          ]
        end

        def self.updatable_fields(context)
          creatable_fields(context)
        end
      end
    end
  end
end

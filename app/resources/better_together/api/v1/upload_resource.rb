# frozen_string_literal: true

module BetterTogether
  module Api
    module V1
      # JSONAPI resource for Upload
      # Scoped to creator via UploadPolicy::Scope
      class UploadResource < ::BetterTogether::Api::ApplicationResource
        model_name '::BetterTogether::Upload'

        translatable_attribute :name

        attributes :privacy
        attribute :file_url
        attribute :filename
        attribute :content_type
        attribute :byte_size

        has_one :creator, class_name: 'Person'

        filter :privacy

        def file_url
          attachment_url(:file)
        end

        def filename
          return unless @model.file.attached?

          @model.file.filename.to_s
        end

        def content_type
          return unless @model.file.attached?

          @model.file.content_type
        end

        def byte_size
          return unless @model.file.attached?

          @model.file.byte_size
        end

        def self.creatable_fields(_context)
          %i[name privacy]
        end

        def self.updatable_fields(_context)
          %i[name privacy]
        end
      end
    end
  end
end

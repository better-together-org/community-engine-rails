# frozen_string_literal: true

module BetterTogether
  # when included, the model will have slugs enabled. Requires a slug db column.
  module FriendlySlug
    extend ActiveSupport::Concern

    included do
      extend Mobility
      extend ::FriendlyId
      translates :slug

      # This method must be called or the class will have validation issues
      def self.slugged(attribute, **options)
        options = { use: %i[slugged history mobility], **options }
        # options = { use: %i[slugged history], **options }

        friendly_id(
          attribute,
          **options.except(:min_length)
        )

        slug_column = options[:slug_column] || :slug
        min_length = options[:min_length] || 3

        validates slug_column, presence: true, uniqueness: true, length: { minimum: min_length }
      end
    end
  end
end

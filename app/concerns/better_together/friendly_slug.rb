# frozen_string_literal: true

module BetterTogether
  # when included, the model will have slugs enabled. Requires a slug db column.
  module FriendlySlug
    extend ActiveSupport::Concern

    included do
      extend Mobility
      extend ::FriendlyId

      # This method must be called or the class will have validation issues
      def self.slugged(attribute, **options)
        translates :slug

        plugins = %i[slugged history mobility]

        options = { use: plugins, **options }

        friendly_id(
          attribute,
          **options.except(:min_length)
        )

        min_length = options[:min_length] || 3

        slug_column = options[:slug_column] || :slug
        validates slug_column, presence: true, uniqueness: true, length: { minimum: min_length }
      end
    end
  end
end

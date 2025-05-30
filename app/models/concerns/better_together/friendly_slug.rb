# frozen_string_literal: true

module BetterTogether
  # when included, the model will have slugs enabled. Requires a slug db column.
  module FriendlySlug
    extend ActiveSupport::Concern

    included do
      include Translatable
      extend ::FriendlyId

      class_attribute :parameterize_slug, default: true

      # This method must be called or the class will have validation issues
      def self.slugged(attribute, **options)
        translates :slug, type: :string

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

      def slug= arg, locale: nil, **options
        arg = arg&.parameterize if self.class.parameterize_slug
        super(arg&.strip, locale:, **options)
      end
    end
  end
end

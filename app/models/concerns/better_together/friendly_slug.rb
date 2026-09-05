# frozen_string_literal: true

module BetterTogether
  # when included, the model will have slugs enabled. Requires a slug db column.
  module FriendlySlug
    extend ActiveSupport::Concern

    module_function

    def normalize_slug_fragment(value)
      value.to_s.parameterize
    end

    def normalize_slug_preserving_namespace(value)
      value.to_s.split('--').map { |fragment| normalize_slug_fragment(fragment) }.reject(&:blank?).join('--').presence
    end

    included do # rubocop:todo Metrics/BlockLength
      include Translatable
      extend ::FriendlyId

      class_attribute :parameterize_slug, default: true

      def self.slugged(attribute, slug_uniqueness: true, scope: nil, **options) # rubocop:todo Metrics/MethodLength
        translates :slug, type: :string

        plugins = %i[slugged history mobility]

        options = { use: plugins, **options }

        friendly_id(
          attribute,
          **options.except(:min_length, :scope, :slug_uniqueness)
        )

        min_length = options[:min_length] || 3

        slug_column = options[:slug_column] || :slug
        if slug_uniqueness
          uniqueness_opts = scope ? { scope: } : true
          validates slug_column, presence: true, uniqueness: uniqueness_opts, length: { minimum: min_length }
        else
          validates slug_column, presence: true, length: { minimum: min_length }
        end
      end

      def slug=(arg, locale: nil, **options)
        arg = BetterTogether::FriendlySlug.normalize_slug_preserving_namespace(arg) if self.class.parameterize_slug

        # Avoid leaking unrelated keywords (like :id from URL helpers) into
        # Mobility/FriendlyId setter, which can be misinterpreted as a locale.
        sanitized = options.dup
        sanitized.delete(:id)

        if locale
          super(arg&.strip, locale:, **sanitized)
        else
          super(arg&.strip, **sanitized)
        end
      end
    end
  end
end

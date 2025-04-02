# frozen_string_literal: true

module BetterTogether
  # Generates a unique identifier for any class that includes this module
  module Identifier
    extend ActiveSupport::Concern

    included do
      include FriendlySlug

      slugged :identifier

      validates :identifier,
                presence: true,
                uniqueness: true,
                length: { maximum: 100 },
                unless: :skip_validate_identifier?

      before_create :generate_identifier_slug
      before_validation :generate_identifier

      def identifier= arg
        self.slug = super arg.parameterize
      end

      def to_param
        slug
      end
    end

    class_methods do
      def extra_permitted_attributes
        super + %i[
          identifier
        ]
      end
    end

    protected

    def generate_identifier
      return if identifier.present?

      self.identifier = loop do
        autogen_identifier = slug&.parameterize || SecureRandom.alphanumeric(10)
        break autogen_identifier unless self.class.exists?(identifier: autogen_identifier)

        autogen_identifier = "#{autogen_identifier}-#{SecureRandom.alphanumeric(10)}"
        break autogen_identifier unless self.class.exists?(identifier: autogen_identifier)
      end
    end

    def generate_identifier_slug # rubocop:todo Metrics/AbcSize
      return slug if respond_to?(:slug) && slug.present?
      return if self[:identifier].blank?

      self.slug = loop do
        autogen_slug = identifier.parameterize
        break autogen_slug unless self.class.base_class.exists?(slug: autogen_slug)

        autogen_slug = "#{autogen_slug}-#{SecureRandom.alphanumeric(10)}"
        break autogen_slug unless self.class.base_class.exists?(slug: autogen_slug)
      end
    end

    def skip_validate_identifier?
      false
    end
  end
end

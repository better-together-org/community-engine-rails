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
                length: { maximum: 100 },
                unless: :skip_validate_identifier?

      # Uniqueness is scoped to platform_id when the model is platform-scoped,
      # otherwise globally unique. Replaces the bare `uniqueness: true` validator
      # so the same identifier can exist on different platforms.
      validate :validate_identifier_uniqueness, unless: :skip_validate_identifier?

      before_create :generate_identifier_slug
      before_validation :generate_identifier

      def identifier=(arg)
        arg = BetterTogether::FriendlySlug.normalize_slug_preserving_namespace(arg) if self.class.parameterize_slug
        self.slug = super(arg&.strip)
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

    def validate_identifier_uniqueness
      return if identifier.blank?

      # Scope uniqueness to platform when platform_id column exists on this model.
      scope = self.class.where(identifier: identifier)
      scope = scope.where(platform_id: platform_id) if has_attribute?(:platform_id)
      scope = scope.where.not(id: id) if persisted?

      errors.add(:identifier, :taken) if scope.exists?
    end

    def generate_identifier
      return if identifier.present?

      self.identifier = loop do
        candidate = slug&.parameterize || SecureRandom.alphanumeric(10)
        break candidate unless identifier_taken?(candidate)

        candidate = "#{candidate}-#{SecureRandom.alphanumeric(10)}"
        break candidate unless identifier_taken?(candidate)
      end
    end

    def identifier_taken?(candidate)
      identifier_scope.exists?(identifier: candidate)
    end

    def identifier_scope
      return self.class.where(platform_id: platform_id) if has_attribute?(:platform_id)

      self.class
    end

    def generate_identifier_slug # rubocop:todo Metrics/AbcSize
      return slug if respond_to?(:slug) && slug.present?
      return if self[:identifier].blank?

      self.slug = loop do
        autogen_slug = BetterTogether::FriendlySlug.normalize_slug_preserving_namespace(identifier)
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

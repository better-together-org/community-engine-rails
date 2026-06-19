# frozen_string_literal: true

module BetterTogether
  # Generates a unique identifier for any class that includes this module
  module Identifier
    extend ActiveSupport::Concern

    included do
      include FriendlySlug

      slugged :identifier, slug_uniqueness: false

      validates :identifier,
                presence: true,
                length: { maximum: 100 },
                unless: :skip_validate_identifier?

      validate :validate_identifier_uniqueness, unless: :skip_validate_identifier?

      validates :slug, uniqueness: { scope: :platform_id }, if: -> { has_attribute?(:platform_id) }
      validates :slug, uniqueness: true, unless: -> { has_attribute?(:platform_id) }

      before_create :generate_identifier_slug
      # Must fire before PlatformScoped's assign_current_platform_if_available overwrites a nil platform_id.
      before_validation :capture_platform_id_for_uniqueness
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

    def capture_platform_id_for_uniqueness
      @platform_id_at_validation_start = has_attribute?(:platform_id) ? read_attribute(:platform_id) : nil
    end

    def validate_identifier_uniqueness
      return if identifier.blank?

      original_platform_id = @platform_id_at_validation_start
      scope = self.class.where(identifier: identifier)
      if has_attribute?(:platform_id) && original_platform_id.present?
        scope = scope.where(platform_id: original_platform_id)
      end
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

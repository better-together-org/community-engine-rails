# frozen_string_literal: true

module BetterTogether
  # Generates a unique identifier for any class that includes this module
  module Identifier
    extend ActiveSupport::Concern

    included do
      include FriendlySlug

      unless :skip_validate_identifier? # rubocop:todo Lint/LiteralAsCondition
        validates :identifier,
                  presence: true,
                  uniqueness: true,
                  length: { maximum: 100 }
      end

      before_create :generate_identifier_slug
      before_validation :generate_identifier
    end

    protected

    def generate_identifier
      return if identifier.present?

      self.identifier = loop do
        autogen_identifier = slug.parameterize
        break autogen_identifier unless self.class.exists?(identifier: autogen_identifier)

        autogen_identifier = "#{autogen_identifier}-#{SecureRandom.alphanumeric(10)}"
        break autogen_identifier unless self.class.exists?(identifier: autogen_identifier)
      end
    end

    def generate_identifier_slug
      return self[:slug] if respond_to?(:slug) && self[:slug].present?
      return if self[:identifier].blank?

      self[:slug] = loop do
        autogen_slug = identifier.parameterize
        break autogen_slug unless self.class.exists?(slug: autogen_slug)

        autogen_slug = "#{autogen_slug}-#{SecureRandom.alphanumeric(10)}"
        break autogen_slug unless self.class.exists?(slug: autogen_slug)
      end
    end

    def skip_validate_identifier?
      false
    end
  end
end

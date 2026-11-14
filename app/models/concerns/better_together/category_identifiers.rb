# frozen_string_literal: true

module BetterTogether
  # Categories by identifier for categorizable content, so an API client can file a record without knowing category
  # ids. Unknown identifiers are rejected with a validation error instead of being silently dropped.
  module CategoryIdentifiers
    extend ActiveSupport::Concern

    included do
      validate :category_identifiers_must_exist
    end

    def category_identifiers
      categories.map(&:identifier)
    end

    def category_identifiers=(identifiers)
      @pending_category_identifiers = Array(identifiers).map(&:to_s).compact_blank.uniq
      found = category_klass.where(identifier: @pending_category_identifiers).to_a
      self.categories = found if found.size == @pending_category_identifiers.size
    end

    private

    def category_klass
      self.class.category_klass
    end

    def category_identifiers_must_exist
      return if @pending_category_identifiers.blank?

      known = category_klass.where(identifier: @pending_category_identifiers).pluck(:identifier)
      missing = @pending_category_identifiers - known
      errors.add(:base, "unknown categories: #{missing.join(', ')}") if missing.any?
    end
  end
end

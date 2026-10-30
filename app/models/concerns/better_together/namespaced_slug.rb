# frozen_string_literal: true

module BetterTogether
  # Keeps forward slashes in slugs of models that set `parameterize_slug = false` (pages). Two steps still flatten
  # them: FriendlyId's slug normalization (String#parameterize on the whole value) and Identifier#generate_identifier,
  # which builds the identifier from slug.parameterize and writes it back to the slug. Each path segment is
  # parameterized on its own instead, and a namespaced slug becomes its own identifier, so a page such as
  # "ships/mt-explora-iii" keeps its slash and the catch-all page route finds it. Include after Identifier.
  module NamespacedSlug
    extend ActiveSupport::Concern

    def normalize_friendly_id(value)
      value.to_s.split('/').map(&:parameterize).reject(&:blank?).join('/')
    end

    protected

    def generate_identifier
      return super unless identifier.blank? && slug.to_s.include?('/')

      candidate = normalize_friendly_id(slug)
      candidate = "#{candidate}-#{SecureRandom.alphanumeric(10)}" if identifier_taken?(candidate)
      self.identifier = candidate
    end
  end
end

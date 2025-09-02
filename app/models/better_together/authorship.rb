# frozen_string_literal: true

module BetterTogether
  # Connects an author (eg: person) to an authorable (eg: post)
  class Authorship < ApplicationRecord
    include Positioned
    include BetterTogether::Creatable

    # Per-request creator context for assigning creator_id during author adds
    thread_mattr_accessor :creator_context_id

    before_validation :assign_creator_from_context, on: :create

    # Set creator context for any authorship creations within the block
    def self.with_creator(person)
      previous = creator_context_id
      self.creator_context_id = person&.id
      yield
    ensure
      self.creator_context_id = previous
    end

    belongs_to :author,
               class_name: 'BetterTogether::Person'
    belongs_to :authorable,
               polymorphic: true

    # Notify authors when they are added to or removed from a Page
    after_commit :notify_added_to_page, on: :create
    after_commit :notify_removed_from_page, on: :destroy

    private

    def assign_creator_from_context
      self.creator_id ||= self.class.creator_context_id
    end

    # rubocop:todo Metrics/AbcSize
    # rubocop:todo Metrics/PerceivedComplexity
    # rubocop:todo Metrics/MethodLength
    # rubocop:todo Metrics/CyclomaticComplexity
    def notify_added_to_page # rubocop:todo Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity
      return unless authorable.is_a?(BetterTogether::Page)
      # Skip notifying if the assigned author created this authorship
      return if creator_id.present? && creator_id == author_id

      # Also skip if the current actor is the same person being added
      return if defined?(::Current) && ::Current.respond_to?(:person) && (::Current.person&.id == author_id)

      actor = defined?(::Current) && ::Current.respond_to?(:person) ? ::Current.person : nil
      BetterTogether::PageAuthorshipNotifier
        .with(record: authorable,
              page_id: authorable.id,
              action: 'added',
              actor_id: actor&.id,
              actor_name: actor&.name)
        .deliver_later(author)
    end
    # rubocop:enable Metrics/CyclomaticComplexity
    # rubocop:enable Metrics/MethodLength
    # rubocop:enable Metrics/PerceivedComplexity

    # rubocop:enable Metrics/AbcSize
    # rubocop:todo Metrics/MethodLength
    def notify_removed_from_page # rubocop:todo Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
      return unless authorable.is_a?(BetterTogether::Page)

      # Skip notifying when the acting person equals the removed author.
      # Prefer creator_context_id (thread-local) when provided, otherwise fall back to Current.person when available.
      return if self.class.creator_context_id.present? && self.class.creator_context_id == author_id
      # Skip notifying if the person removing is the same as the removed author
      return if defined?(::Current) && ::Current.respond_to?(:person) && (::Current.person&.id == author_id)

      actor = defined?(::Current) && ::Current.respond_to?(:person) ? ::Current.person : nil
      BetterTogether::PageAuthorshipNotifier
        .with(record: authorable,
              page_id: authorable.id,
              action: 'removed',
              actor_id: actor&.id,
              actor_name: actor&.name)
        .deliver_later(author)
    end
    # rubocop:enable Metrics/MethodLength
  end
end

# frozen_string_literal: true

module BetterTogether
  # Connects an author (eg: person) to an authorable (eg: post)
  class Authorship < ApplicationRecord
    include Positioned

    belongs_to :author,
               class_name: 'BetterTogether::Person'
    belongs_to :authorable,
               polymorphic: true

    # Notify authors when they are added to or removed from a Page
    after_commit :notify_added_to_page, on: :create
    after_commit :notify_removed_from_page, on: :destroy

    private

    def notify_added_to_page
      return unless authorable.is_a?(BetterTogether::Page)

      actor = defined?(::Current) && ::Current.respond_to?(:person) ? ::Current.person : nil
      BetterTogether::PageAuthorshipNotifier
        .with(record: authorable,
              page_id: authorable.id,
              action: 'added',
              actor_id: actor&.id,
              actor_name: actor&.name)
        .deliver_later(author)
    end

    def notify_removed_from_page
      return unless authorable.is_a?(BetterTogether::Page)

      actor = defined?(::Current) && ::Current.respond_to?(:person) ? ::Current.person : nil
      BetterTogether::PageAuthorshipNotifier
        .with(record: authorable,
              page_id: authorable.id,
              action: 'removed',
              actor_id: actor&.id,
              actor_name: actor&.name)
        .deliver_later(author)
    end
  end
end

# frozen_string_literal: true

module BetterTogether
  # Connects a governed contributor to an authorable record with explicit role metadata.
  class Authorship < ApplicationRecord
    include Positioned
    include Citable
    include Claimable
    include BetterTogether::Creatable

    AUTHOR_ROLE = 'author'
    EDITOR_ROLE = 'editor'
    REVIEWER_ROLE = 'reviewer'
    TRANSLATOR_ROLE = 'translator'
    IDEA_SOURCE_ROLE = 'idea_source'
    MODERATOR_ROLE = 'moderator'
    EXCHANGE_INITIATOR_ROLE = 'exchange_initiator'
    EXCHANGE_PARTICIPANT_ROLE = 'exchange_participant'

    CONTENT_CONTRIBUTION = 'content'
    CODE_CONTRIBUTION = 'code'
    DOCUMENTATION_CONTRIBUTION = 'documentation'
    FINANCIAL_CONTRIBUTION = 'financial'
    GOVERNANCE_CONTRIBUTION = 'governance'
    OPERATIONS_CONTRIBUTION = 'operations'
    COMMUNITY_EXCHANGE_CONTRIBUTION = 'community_exchange'
    RESEARCH_CONTRIBUTION = 'research'

    # Per-request creator context for assigning creator_id during author adds
    thread_mattr_accessor :creator_context_id

    before_validation :assign_creator_from_context, on: :create
    before_validation :normalize_role_and_contribution_type

    # Set creator context for any authorship creations within the block
    def self.with_creator(person)
      previous = creator_context_id
      self.creator_context_id = person&.id
      yield
    ensure
      self.creator_context_id = previous
    end

    AUTHOR_TYPES = [
      'BetterTogether::Person',
      'BetterTogether::Robot'
    ].freeze

    belongs_to :author,
               polymorphic: true
    belongs_to :authorable,
               polymorphic: true

    validates :author_type, inclusion: { in: AUTHOR_TYPES }
    alias contributor author
    alias contributable authorable

    scope :for_role, ->(role) { where(role: role.to_s) }
    scope :for_contribution_type, ->(contribution_type) { where(contribution_type: contribution_type.to_s) }
    scope :authors, -> { for_role(AUTHOR_ROLE) }

    validates :role, presence: true, format: { with: /\A[a-z0-9_]+\z/ }
    validates :contribution_type, presence: true, format: { with: /\A[a-z0-9_]+\z/ }

    # Notify authors when they are added to or removed from a Page
    after_commit :notify_added_to_page, on: :create
    after_commit :notify_removed_from_page, on: :destroy

    def author_role?
      role == AUTHOR_ROLE
    end

    def common_role?
      common_roles.include?(role)
    end

    def common_roles
      [
        AUTHOR_ROLE,
        EDITOR_ROLE,
        REVIEWER_ROLE,
        TRANSLATOR_ROLE,
        IDEA_SOURCE_ROLE,
        MODERATOR_ROLE,
        EXCHANGE_INITIATOR_ROLE,
        EXCHANGE_PARTICIPANT_ROLE
      ]
    end

    private

    def assign_creator_from_context
      self.creator_id ||= self.class.creator_context_id
    end

    def normalize_role_and_contribution_type
      self.role = role.presence || AUTHOR_ROLE
      self.contribution_type = contribution_type.presence || CONTENT_CONTRIBUTION
    end

    # rubocop:todo Metrics/AbcSize
    # rubocop:todo Metrics/PerceivedComplexity
    # rubocop:todo Metrics/MethodLength
    # rubocop:todo Metrics/CyclomaticComplexity
    def notify_added_to_page # rubocop:todo Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity
      return unless authorable.is_a?(BetterTogether::Page)
      return unless author_role?
      return unless author.is_a?(BetterTogether::Person)
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
      return unless author_role?
      return unless author.is_a?(BetterTogether::Person)

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

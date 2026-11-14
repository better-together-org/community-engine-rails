# frozen_string_literal: true

module BetterTogether
  # Append-only record of who changed which snippet and how. Survives snippet deletion.
  class PlatformSnippetAudit < ApplicationRecord
    belongs_to :platform, class_name: '::BetterTogether::Platform'

    ACTIONS = %w[created updated enabled disabled destroyed].freeze

    validates :action, inclusion: { in: ACTIONS }

    before_update { raise ActiveRecord::ReadOnlyRecord }
    before_destroy { raise ActiveRecord::ReadOnlyRecord }

    scope :recent, -> { order(created_at: :desc) }

    # Records one event. Content is kept in full so a bad change can be reviewed and reverted.
    def self.record!(snippet:, action:, actor: Current.person, changes: snippet.saved_changes)
      create!(platform_id: snippet.platform_id, snippet_id: snippet.id, snippet_name: snippet.name,
              actor_id: actor&.id, action:, change_set: changes.except('updated_at', 'lock_version', 'updated_by_id'))
    end
  end
end

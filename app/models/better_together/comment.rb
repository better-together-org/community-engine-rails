# frozen_string_literal: true

module BetterTogether
  # A short text comment posted on a commentable record (MVP: BetterTogether::Post).
  class Comment < PlatformRecord
    include Creatable
    include BlockFilterable

    # App-layer whitelist only, no DB constraint (same pattern as Report::ALLOWED_REPORTABLES) —
    # tracked as a follow-up to consider hardening if a bulk-write/import path is ever added.
    ALLOWED_COMMENTABLES = [
      'BetterTogether::Post'
    ].freeze

    belongs_to :commentable, polymorphic: true

    # No dependent: option deliberately — Report/Safety::Case are the moderation audit trail and
    # must survive the reported Comment being deleted (matches how Post/Page/Event/Community/
    # Message, the other Report::ALLOWED_REPORTABLES, already behave: none of them declare a
    # reports_received association at all, so their reports already survive deletion).
    has_many :reports_received, as: :reportable, class_name: 'BetterTogether::Report'

    validates :content, presence: true
    validates :commentable_type, inclusion: { in: ALLOWED_COMMENTABLES }

    scope :oldest_first, -> { order(created_at: :asc) }

    # _later (job-queued) matches Message's pattern — broadcast_append_to's synchronous
    # render happens via the host app's bare ApplicationController.render (Rails engines
    # don't get their own render context here), which has none of this engine's helpers/
    # Pundit mixed in. broadcast_remove_to is unaffected (Turbo passes render: false for
    # removals, so no template is ever rendered for it).
    after_create_commit -> { broadcast_append_later_to commentable, target: comments_stream_target }
    after_destroy_commit -> { broadcast_remove_to commentable }

    def to_s
      content
    end

    def comments_stream_target
      ActionView::RecordIdentifier.dom_id(commentable, :comments)
    end
  end
end

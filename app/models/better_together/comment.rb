# frozen_string_literal: true

module BetterTogether
  # A short text comment posted on a commentable record (MVP: BetterTogether::Post).
  class Comment < PlatformRecord
    include Creatable
    include BlockFilterable

    ALLOWED_COMMENTABLES = [
      'BetterTogether::Post'
    ].freeze

    belongs_to :commentable, polymorphic: true

    has_many :reports_received, as: :reportable, class_name: 'BetterTogether::Report', dependent: :destroy

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

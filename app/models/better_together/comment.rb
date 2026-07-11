# frozen_string_literal: true

module BetterTogether
  # A short text comment posted on a commentable record (MVP: BetterTogether::Post).
  class Comment < PlatformRecord
    include BlockFilterable
    include Creatable
    include Reportable

    belongs_to :commentable, polymorphic: true

    validates :content, presence: true, length: { maximum: 10_000 }
    # Dynamic extension point, not a gem-owned allow-list: a host app opts a model into
    # comments by including BetterTogether::Commentable, nothing else. See
    # docs/developers/architecture/polymorphic_allowlist_extension_audit.md
    validates :commentable_type, inclusion: {
      in: ->(_record) { BetterTogether::Commentable.included_in_models.map(&:name) }
    }

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

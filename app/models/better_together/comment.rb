# frozen_string_literal: true

module BetterTogether
  # A short text comment posted on a commentable record (MVP: BetterTogether::Post).
  class Comment < PlatformRecord
    include BlockFilterable
    include Creatable
    include Reportable
    include Broadcastable

    belongs_to :commentable, polymorphic: true

    validates :content, presence: true, length: { maximum: 10_000 }
    # Dynamic extension point, not a gem-owned allow-list: a host app opts a model into
    # comments by including BetterTogether::Commentable, nothing else. See
    # docs/developers/architecture/polymorphic_allowlist_extension_audit.md
    validates :commentable_type, inclusion: {
      in: ->(_record) { BetterTogether::Commentable.included_in_models.map(&:name) }
    }

    scope :oldest_first, -> { order(created_at: :asc) }

    broadcasts_async_to :commentable, target: :comments_stream_target, on_destroy: true

    def to_s
      content
    end

    def comments_stream_target
      commentable.comments_stream_target
    end

    # Single source of truth for this comment's own dom id, mirroring
    # Commentable#comments_stream_target — previously recomputed independently via
    # dom_id(comment)/dom_id(@comment) in _comment.html.erb,
    # CommentAddedNotifier#comment_url, and comment_mailer/added.html.erb.
    def anchor_id
      ActionView::RecordIdentifier.dom_id(self)
    end
  end
end

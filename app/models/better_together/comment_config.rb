# frozen_string_literal: true

module BetterTogether
  # Per-commentable settings controlling who can post comments and who can see them.
  # Absence of a row means "inherit" for both dimensions — see Commentable's lazy
  # comment_permission/comment_visibility accessors, which read this default without
  # requiring a row to exist.
  class CommentConfig < ApplicationRecord
    belongs_to :commentable, polymorphic: true

    # prefix: true is required on both enums — they share value names (inherit/community),
    # which would otherwise collide on the generated inherit?/community? query methods.
    enum :permission, { inherit: 'inherit', community: 'community', disabled: 'disabled' },
         prefix: true, default: 'inherit'
    enum :visibility, { inherit: 'inherit', community: 'community' },
         prefix: true, default: 'inherit'

    # Dynamic extension point, not a gem-owned allow-list: a model becomes eligible for
    # comment configuration the same way it becomes commentable — by including
    # BetterTogether::Commentable. See
    # docs/developers/architecture/polymorphic_allowlist_extension_audit.md
    validates :commentable_type, inclusion: {
      in: ->(_record) { BetterTogether::Commentable.included_in_models.map(&:name) }
    }

    def self.permitted_attributes(id: false, destroy: false)
      attrs = %i[permission visibility]
      attrs += %i[id] if id
      attrs += %i[_destroy] if destroy
      attrs
    end
  end
end

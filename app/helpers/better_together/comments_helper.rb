# frozen_string_literal: true

module BetterTogether
  # Helper methods for rendering comment moderation controls safely both in a
  # normal request/view context and in the bare renderer Turbo uses for
  # background broadcast_append_to/broadcast_remove_to jobs (no Warden/current_user
  # there — mirrors ContentActionsHelper#can_report_record?'s rescue pattern).
  module CommentsHelper
    def comment_action_items(comment)
      return [] unless can_delete_comment?(comment)

      [delete_comment_action_item(comment)]
    end

    def can_delete_comment?(comment)
      return false unless current_user.present? && current_person.present?

      BetterTogether::CommentPolicy.new(current_user, comment).destroy?
    rescue Devise::MissingWarden
      false
    end

    # Returns a symbol explaining why the current person can't post a new comment on
    # `commentable`, or nil if they can. Only called once the caller has already
    # confirmed the comment thread itself is visible to them (comment_visibility
    # permits) — this is about the *create*-specific gate, not thread visibility.
    # One place to compute this instead of the view re-deriving policy state ad hoc
    # across several if/elsif branches.
    def comment_denial_reason(commentable)
      return nil if policy(BetterTogether::Comment.new(commentable:)).create?
      return :sign_in_required unless current_user.present?

      permission_reason = comment_permission_denial_reason(commentable)
      return permission_reason if permission_reason
      return :publishing_agreement_required if current_person_missing_publishing_agreement?

      :sign_in_required
    end

    private

    def comment_permission_denial_reason(commentable)
      return unless commentable.respond_to?(:comment_permission)

      case commentable.comment_permission
      when 'disabled' then :disabled
      when 'community' then :community_required
      end
    end

    def delete_comment_action_item(comment)
      {
        id: 'delete',
        href: comment_path(comment),
        icon: 'fa-trash-can',
        label: t('better_together.comments.delete', default: 'Delete comment'),
        data: { turbo_method: :delete, turbo_confirm: t('globals.confirm_delete') }
      }
    end
  end
end

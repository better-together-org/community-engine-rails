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

    private

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

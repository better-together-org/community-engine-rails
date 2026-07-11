# frozen_string_literal: true

module BetterTogether
  # Sends email notifications when a comment is added to the recipient's content
  class CommentMailer < ApplicationMailer
    def added
      @comment = params[:comment]
      @commentable = @comment.commentable
      @recipient = params[:recipient]

      self.locale = @recipient.locale
      self.time_zone = @recipient.time_zone

      mail(to: @recipient.email, subject: t('better_together.comment_mailer.added.subject'))
    end
  end
end

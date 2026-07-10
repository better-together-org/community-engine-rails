# frozen_string_literal: true

module BetterTogether
  # Handles creating and removing comments on commentable records (MVP: posts).
  class CommentsController < ApplicationController
    include ChecksRequiredAgreements

    before_action :authenticate_user!
    before_action :disallow_robots
    before_action :check_content_publishing_agreement, only: :create
    before_action :set_comment, only: :destroy

    def create
      @commentable = resolve_commentable
      return render_invalid_commentable unless @commentable

      @comment = @commentable.comments.new(comment_params)
      @comment.creator = helpers.current_person
      authorize @comment

      save_comment_and_notify

      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to polymorphic_path(@commentable) }
      end
    end

    def destroy
      authorize @comment
      @commentable = @comment.commentable
      @comment.destroy

      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to polymorphic_path(@commentable) }
      end
    end

    private

    def save_comment_and_notify
      if @comment.save
        notify_commentable_owners(@comment)
      else
        flash[:alert] = @comment.errors.full_messages.to_sentence
      end
    end

    def set_comment
      @comment = policy_scope(Comment).find(params[:id])
    end

    def resolve_commentable
      klass = BetterTogether::SafeClassResolver.resolve(
        params[:commentable_type],
        allowed: BetterTogether::Commentable.included_in_models.map(&:name)
      )
      return nil unless klass

      klass.find_by(id: params[:commentable_id])
    end

    def render_invalid_commentable
      skip_authorization
      head :not_found
    end

    def comment_params
      params.require(:comment).permit(:content)
    end

    # Notifies the commentable's credited authors (not just its DB-row creator) — a Post's
    # creator and its Authorable authors can diverge (staff-assisted or co-authored posts),
    # and the author(s) are who this feature is meant to reach.
    def notify_commentable_owners(comment)
      commentable = comment.commentable
      recipients = commentable.respond_to?(:governed_authors) ? commentable.governed_authors : [commentable.try(:creator)]
      recipients = recipients.compact.uniq - [comment.creator]
      return if recipients.empty?

      BetterTogether::CommentAddedNotifier.with(record: comment, comment: comment).deliver_later(recipients)
    end
  end
end

# frozen_string_literal: true

module BetterTogether
  # Handles creating and removing comments on commentable records (MVP: posts).
  class CommentsController < ApplicationController
    before_action :authenticate_user!
    before_action :disallow_robots
    before_action :set_comment, only: :destroy

    def create
      @commentable = resolve_commentable
      return render_invalid_commentable unless @commentable

      @comment = @commentable.comments.new(comment_params)
      @comment.creator = helpers.current_person
      authorize @comment

      notify_commentable_creator(@comment) if @comment.save

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

    def set_comment
      @comment = policy_scope(Comment).find(params[:id])
    end

    def resolve_commentable
      klass = BetterTogether::SafeClassResolver.resolve(
        params[:commentable_type],
        allowed: BetterTogether::Comment::ALLOWED_COMMENTABLES
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

    def notify_commentable_creator(comment)
      recipient = comment.commentable.try(:creator)
      return if recipient.blank? || recipient == comment.creator

      BetterTogether::CommentAddedNotifier.with(record: comment, comment: comment).deliver_later(recipient)
    end
  end
end

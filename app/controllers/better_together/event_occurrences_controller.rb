# frozen_string_literal: true

module BetterTogether
  # Per-session actions for one occurrence of a recurring Event: RSVP,
  # comment, and (Part 2) organizer overrides. Lazily creates the
  # EventOccurrence row via Event#find_or_create_occurrence_for — only ever
  # on an actual write (RSVP/comment/override), never from a read/display
  # path. :occurrence_date in the route is an ISO8601 date, not a
  # persisted record id.
  class EventOccurrencesController < ApplicationController
    include ChecksRequiredAgreements

    before_action :set_event
    before_action :set_occurrence_date
    # RSVP actions use a manual current_person check (below), matching
    # EventsController#rsvp_update/#rsvp_cancel's custom redirect+message —
    # only the comments action hard-requires sign-in, matching CommentsController.
    before_action :authenticate_user!, only: :comments
    before_action :disallow_robots, only: :comments
    before_action :check_content_publishing_agreement, only: :comments

    # Organizer per-occurrence override (location/time/description/
    # cancelled). Builds (not creates) the occurrence first and authorizes
    # against that in-memory record before persisting anything — a denied
    # attempt never creates a row, unlike the RSVP/comment actions where
    # find_or_create_occurrence_for is correct because those actions are
    # already gated by an earlier authorize call.
    def update
      occurrence = @event.event_occurrences.find_or_initialize_by(occurrence_date: @occurrence_date)
      authorize occurrence

      if occurrence.update(occurrence_params)
        redirect_to @event, notice: t('better_together.events.occurrences.override_saved')
      else
        redirect_to @event, alert: occurrence.errors.full_messages.to_sentence
      end
    end

    # RSVP actions — mirror EventsController's rsvp_interested/rsvp_going/
    # rsvp_cancel exactly, scoped to one occurrence instead of the series.
    def rsvp_interested
      rsvp_update('interested')
    end

    def rsvp_going
      rsvp_update('going')
    end

    def rsvp_cancel
      authorize @event, :show?

      current_person = helpers.current_person
      unless current_person
        redirect_to @event, alert: t('better_together.events.login_required')
        return
      end

      occurrence = @event.find_or_create_occurrence_for(@occurrence_date)
      attendance = BetterTogether::EventAttendance.find_by(
        event: @event, event_occurrence: occurrence, person: current_person
      )
      attendance&.destroy
      redirect_to @event, notice: occurrence_confirmation_message('rsvp_cancelled_for_date')
    end

    # Session-specific comment — reuses Comment/Commentable exactly as
    # CommentsController does for Post, just with the commentable resolved
    # to this occurrence (lazily created here) instead of taken from params.
    def comments # rubocop:todo Metrics/AbcSize
      authorize @event, :show?

      occurrence = @event.find_or_create_occurrence_for(@occurrence_date)
      authorize occurrence, :show?

      @comment = occurrence.comments.new(comment_params)
      @comment.creator = helpers.current_person
      # Explicit :create? — CommentPolicy has no #comments? and the default
      # Pundit inference would otherwise look for one, since action_name
      # here is "comments", not "create".
      authorize @comment, :create?

      if @comment.save
        redirect_to @event, notice: t('better_together.events.occurrences.comment_saved')
      else
        redirect_to @event, alert: @comment.errors.full_messages.to_sentence
      end
    end

    private

    def set_event
      @event = BetterTogether::Event.friendly.find(params[:event_id])
    rescue ActiveRecord::RecordNotFound
      head :not_found
    end

    def set_occurrence_date
      return if performed?

      @occurrence_date = Date.iso8601(params[:occurrence_date])
    rescue ArgumentError, TypeError
      redirect_to @event, alert: t('better_together.events.occurrences.invalid_date')
    end

    def rsvp_update(status) # rubocop:todo Metrics/AbcSize, Metrics/MethodLength
      return if performed?

      authorize @event, :show?

      unless @event.scheduled?
        redirect_to @event, alert: t('better_together.events.rsvp_not_available')
        return
      end

      current_person = helpers.current_person
      unless current_person
        redirect_to new_user_session_path(locale: I18n.locale), alert: t('better_together.events.login_required')
        return
      end

      occurrence = @event.find_or_create_occurrence_for(@occurrence_date)
      attendance = BetterTogether::EventAttendance.find_or_initialize_by(event: @event, event_occurrence: occurrence,
                                                                         person: current_person)
      attendance.status = status
      authorize attendance

      if attendance.save
        redirect_to @event, notice: occurrence_confirmation_message('rsvp_saved_for_date')
      else
        redirect_to @event, alert: attendance.errors.full_messages.to_sentence
      end
    end

    def comment_params
      params.require(:comment).permit(:content)
    end

    def occurrence_params
      params.require(:event_occurrence).permit(*BetterTogether::EventOccurrence.permitted_attributes)
    end

    # Names the specific session date in the confirmation, not just the
    # series — a per-occurrence action easily reads as "did that apply to
    # every week?" without it.
    def occurrence_confirmation_message(key)
      t("better_together.events.occurrences.#{key}", date: l(@occurrence_date, format: :long))
    end
  end
end

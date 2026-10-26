# frozen_string_literal: true

module BetterTogether
  # Web side of cancelling or deleting an event series: the confirmation panel on the series page sends
  # +session_disposition+ (cancel, delete or promote) and the series' sessions are handled with it. Without a choice
  # nothing changes and the person is told why. Included in EventsController.
  module EventSeriesActions
    def update
      return super unless cancelling_series?

      authorize_resource
      dispose_series { @resource.cancel_series!(sessions: params[:session_disposition]) }
    end

    def destroy
      return super unless @resource.series? && @resource.sessions.any?

      authorize_resource
      dispose_series(redirect: events_path) { @resource.destroy_series!(sessions: params[:session_disposition]) }
    end

    private

    def cancelling_series?
      @resource.series? && params[:series_action] == 'cancel'
    end

    def dispose_series(redirect: nil)
      yield
      redirect_to redirect || event_path(@resource), notice: t('better_together.events.series.disposed')
    rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotDestroyed
      redirect_to event_path(@resource), alert: @resource.errors.full_messages.to_sentence
    end
  end
end

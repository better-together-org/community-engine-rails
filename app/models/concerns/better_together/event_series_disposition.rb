# frozen_string_literal: true

module BetterTogether
  # What happens to a series' sessions when the series is cancelled or deleted. Nothing is decided for the
  # caller: it must say +sessions: 'cancel'+ or +'delete'+ them, or +'promote'+ them to standalone events.
  # Past sessions are never cancelled. The whole action rolls back if any session cannot be changed.
  module EventSeriesDisposition
    extend ActiveSupport::Concern

    CANCEL_CHOICES = %w[cancel promote].freeze
    DELETE_CHOICES = %w[delete promote].freeze

    included do
      attr_accessor :session_disposition

      before_destroy :settle_sessions_before_destroy, prepend: true, if: :series?
      after_save :settle_sessions_after_cancel, if: :series_cancelled_now?
      validate :cancelling_a_series_needs_a_choice
    end

    # Cancels the series and, as chosen, its upcoming sessions ('cancel') or all of them as standalone events
    # ('promote').
    def cancel_series!(sessions:)
      self.session_disposition = sessions
      update!(status: 'cancelled')
    end

    # Deletes the series and, as chosen, its sessions ('delete') or leaves them standalone ('promote').
    def destroy_series!(sessions:)
      self.session_disposition = sessions
      destroy!
    end

    private

    def cancelling_a_series_needs_a_choice
      return unless series? && status_cancelled? && will_save_change_to_status? && live_sessions.any?
      return if CANCEL_CHOICES.include?(session_disposition.to_s)

      errors.add(:session_disposition, 'must be cancel or promote: say what happens to the sessions')
    end

    def series_cancelled_now?
      series? && saved_change_to_status? && status_cancelled?
    end

    def settle_sessions_after_cancel
      affected = live_sessions.reject { |session| session.starts_at&.past? }
      case session_disposition.to_s
      when 'cancel' then affected.each { |session| session.update!(status: 'cancelled') }
      when 'promote' then promote_sessions
      end
      log_settlement('cancel', affected)
    end

    def settle_sessions_before_destroy
      return if sessions.none?
      return refuse_destroy_without_choice unless DELETE_CHOICES.include?(session_disposition.to_s)

      affected = sessions.to_a
      session_disposition.to_s == 'delete' ? affected.each(&:destroy!) : promote_sessions
      log_settlement('delete', affected)
    end

    def refuse_destroy_without_choice
      errors.add(:session_disposition, 'must be delete or promote: say what happens to the sessions')
      throw :abort
    end

    def promote_sessions
      series_session_links.destroy_all
      series_session_links.reset
    end

    def log_settlement(action, affected)
      Rails.logger.info(
        "[EventSeries] #{action} series #{identifier}: sessions #{session_disposition} " \
        "(#{affected.map(&:identifier).join(', ')})"
      )
    end
  end
end

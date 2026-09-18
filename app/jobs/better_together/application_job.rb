# frozen_string_literal: true

module BetterTogether
  # Base job class for Better Together background work.
  class ApplicationJob < ActiveJob::Base
    discard_on ActiveStorage::FileNotFoundError

    # Routes job exceptions through the same BetterTogether.report_error adapter
    # dispatch used by ApplicationController#handle_error, so host apps only need
    # to register an error_reporting adapter once to get both request- and
    # job-level coverage.
    #
    # Deliberately an around_perform, not rescue_from: ActiveJob's retry_on/
    # discard_on are themselves implemented as rescue_from handlers, and a
    # rescue_from(StandardError) declared here would take precedence over a
    # subclass's own retry_on StandardError (several jobs declare exactly
    # that), silently breaking their retry behavior. around_perform runs
    # inside ActiveJob's own perform_now rescue boundary, so re-raising here
    # still lets the subclass's retry_on/discard_on/rescue_from resolve
    # normally afterward.
    around_perform do |_job, block|
      block.call
    rescue StandardError => e
      handle_job_error(e)
    end

    private

    def handle_job_error(exception)
      raise exception unless Rails.env.production?

      log_job_error(exception)
      report_job_error(exception)

      raise exception
    end

    def log_job_error(exception)
      Rails.logger.error(
        "[PRODUCTION][JobException] #{exception.class}: #{exception.message} " \
        "job_class=#{self.class.name} job_id=#{job_id} queue=#{queue_name} executions=#{executions}"
      )
      Rails.logger.error(exception.backtrace.first(25).join("\n")) if exception.backtrace
    end

    def report_job_error(exception)
      BetterTogether.report_error(exception, context: job_error_context)
    rescue StandardError => e
      Rails.logger.error("[PRODUCTION][ErrorReportingFailure] #{e.class}: #{e.message}")
    end

    def job_error_context
      {
        job_id: job_id,
        job_class: self.class.name,
        queue_name: queue_name,
        executions: executions
      }
    end
  end
end

# frozen_string_literal: true

module BetterTogether
  # Background jobs tab of the host dashboard: a live summary panel read from the Sidekiq API and the
  # Sidekiq UI framed in the page. The routes are also constrained by HostJobsConstraint.
  class HostJobsController < ApplicationController
    skip_third_party_tracking

    before_action :authorize_jobs

    def show; end

    def sidekiq; end

    def summary
      @summary = HostJobs::Summary.call
      @link_context = params[:context] == 'tab' ? 'tab' : 'overview'
    end

    private

    def authorize_jobs
      authorize :host_jobs, :show?, policy_class: HostJobsPolicy
    end
  end
end

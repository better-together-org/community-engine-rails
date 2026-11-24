# frozen_string_literal: true

# Capture command (run from repo root):
#   bin/dc-run bash -c 'RUN_DOCS_SCREENSHOTS=1 bundle exec prspec spec/docs_screenshots/better_together/host_jobs_spec.rb'
#
# Documents the background jobs tab (summary panel and framed Sidekiq UI) and the panel on the
# host dashboard overview.

require 'rails_helper'

RSpec.describe 'Documentation screenshots for host background jobs', # rubocop:disable RSpec/SpecFilePathSuffix
               :docs_screenshot, :js, retry: 0, type: :feature do
  include BetterTogether::CapybaraFeatureHelpers
  include AutomaticTestConfiguration

  let(:locale) { I18n.default_locale }
  let!(:host_platform) { configure_host_platform }
  let(:processes) { 1 }

  def snapshot
    queues = [%w[default 12 45.0], %w[mailers 3 8.0], %w[weather 0 0.0]].map do |name, size, latency|
      BetterTogether::HostJobs::Summary::QueueRow.new(name:, size: size.to_i, latency: latency.to_f)
    end
    BetterTogether::HostJobs::Summary::Snapshot.new(
      available: true, failed: 18, retrying: 4, dead: 2, scheduled: 6, enqueued: 15, queues:,
      longest_latency: 45.0, busy: 3, stalled: 1, processes:, stalled_after: 10.minutes, fetched_at: Time.current
    )
  end

  before do
    skip 'Set RUN_DOCS_SCREENSHOTS=1 to generate documentation screenshots.' unless ENV['RUN_DOCS_SCREENSHOTS'] == '1'
    allow(BetterTogether::HostJobs::Summary).to receive(:call) { snapshot }
  end

  def capture(name, callouts:, &)
    BetterTogether::CapybaraScreenshotEngine.capture(
      name, device: :both,
            metadata: { locale:, role: 'platform_steward', feature_set: 'host_jobs', flow: name,
                        source_spec: self.class.metadata[:file_path] },
            callouts:, &
    )
  end

  [false, true].each do |annotated|
    it "captures the background jobs tab#{' annotated' if annotated}" do
      name = "host_jobs_tab#{'_annotated' if annotated}"
      callouts = if annotated
                   [{ selector: '#host-jobs-summary-stats', title: 'Live summary', position: 'below',
                      bullets: ['Refreshes every 30 seconds while the tab is visible.',
                                'Counts link straight to the Sidekiq page.'] }]
                 else
                   []
                 end
      result = capture(name, callouts:) do
        capybara_login_as_platform_manager
        visit better_together.host_jobs_path(locale:)
        expect(page).to have_css('#host-jobs-summary-stats', wait: 10)
        expect(page).to have_css('iframe#host-jobs-sidekiq-iframe', wait: 10)
        find('#host-jobs-summary-panel').scroll_to(:top)
      end

      expect(result[:desktop]).to end_with("docs/screenshots/desktop/#{name}.png")
      expect(result[:mobile]).to end_with("docs/screenshots/mobile/#{name}.png")
    end

    it "captures the framed Sidekiq UI#{' annotated' if annotated}" do
      name = "host_jobs_sidekiq_frame#{'_annotated' if annotated}"
      callouts = if annotated
                   [{ selector: '#host-jobs-sidekiq-embed', title: 'Sidekiq in the page', position: 'above',
                      bullets: ['Same-origin iframe in the current language.',
                                'Open it in a new tab with the button above.'] }]
                 else
                   []
                 end
      result = capture(name, callouts:) do
        capybara_login_as_platform_manager
        visit better_together.host_jobs_path(locale:)
        iframe = find('iframe#host-jobs-sidekiq-iframe', wait: 10)
        within_frame(iframe) { expect(page).to have_css('html[lang="en"]', visible: :all, wait: 10) }
        find('#host-jobs-sidekiq-embed').scroll_to(:top)
      end

      expect(result[:desktop]).to end_with("docs/screenshots/desktop/#{name}.png")
    end
  end

  context 'when no worker process is running' do
    let(:processes) { 0 }

    [false, true].each do |annotated|
      it "captures the dashboard overview panel with no workers#{' annotated' if annotated}" do
        name = "host_jobs_overview_no_workers#{'_annotated' if annotated}"
        callouts = if annotated
                     [{ selector: '#host-jobs-no-processes', title: 'No workers', position: 'below',
                        bullets: ['Zero worker processes is the clearest stalled signal.'] }]
                   else
                     []
                   end
        result = capture(name, callouts:) do
          capybara_login_as_platform_manager
          visit better_together.host_dashboard_path(locale:)
          expect(page).to have_css('#host-jobs-no-processes', wait: 10)
          find('#host-jobs-summary-panel').scroll_to(:top)
        end

        expect(result[:mobile]).to end_with("docs/screenshots/mobile/#{name}.png")
      end
    end
  end
end

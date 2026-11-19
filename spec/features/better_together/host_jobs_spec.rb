# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Host background jobs tab', :accessibility, :js, :no_auth, retry: 0 do
  include BetterTogether::CapybaraFeatureHelpers

  let(:locale) { I18n.default_locale }
  let(:counts) { { failed: 3, retrying: 2, dead: 1 } }

  def snapshot(**overrides)
    BetterTogether::HostJobs::Summary::Snapshot.new(
      available: true, scheduled: 0, enqueued: 4,
      queues: [BetterTogether::HostJobs::Summary::QueueRow.new(name: 'default', size: 4, latency: 30.0)],
      longest_latency: 30.0, busy: 1, stalled: 0, processes: 1, stalled_after: 10.minutes,
      fetched_at: Time.current, **counts, **overrides
    )
  end

  def reload_summary
    page.execute_script("document.getElementById('host-jobs-summary').reload()")
  end

  before do
    allow(BetterTogether::HostJobs::Summary).to receive(:call) { snapshot }
    # :no_auth plus an explicit sign-in: the description-based auto-login can pick a regular user here.
    find_or_create_test_user('manager@example.test', 'SecureTest123!@#', :platform_manager)
    capybara_login_as_platform_manager
  end

  it 'loads the live summary and the framed Sidekiq UI', :aggregate_failures do
    visit better_together.host_jobs_path(locale:)

    expect(page).to have_css('#host-jobs-summary-stats #host-jobs-failed-count', text: '3', wait: 10)
    expect(page).to have_css('iframe#host-jobs-sidekiq-iframe', wait: 10)
    within_frame('host-jobs-sidekiq-iframe') do
      expect(page).to have_css('html[lang="en"]', visible: :all, wait: 10)
      expect(page).to have_link(href: %r{/sidekiq/retries})
    end
  end

  it 'keeps Sidekiq navigation inside the iframe' do
    visit better_together.host_jobs_path(locale:)
    jobs_url = page.current_url

    within_frame(find('iframe#host-jobs-sidekiq-iframe', wait: 10)) do
      find("a[href$='/sidekiq/retries']", match: :first).click
      page.document.synchronize(10) do
        raise Capybara::ExpectationNotMet unless page.evaluate_script('window.location.pathname') == '/sidekiq/retries'
      end
    end
    expect(page.current_url).to eq(jobs_url)
  end

  it 'shows Sidekiq in the page locale' do
    visit better_together.host_jobs_path(locale: :fr)

    within_frame(find('iframe#host-jobs-sidekiq-iframe', wait: 10)) do
      expect(page).to have_css('html[lang="fr"]', visible: :all, wait: 10)
    end
  end

  it 'announces only when a trouble count rises', :aggregate_failures do
    visit better_together.host_jobs_path(locale:)
    expect(page).to have_css('#host-jobs-failed-count', text: '3', wait: 10)

    reload_summary
    expect(page).to have_css('#host-jobs-summary-updated', wait: 10)
    expect(find('#host-jobs-summary-status', visible: :all).text(:all)).to be_empty

    counts[:failed] = 5
    reload_summary
    expect(page).to have_css('#host-jobs-failed-count', text: '5', wait: 10)
    expect(page).to have_css('#host-jobs-summary-status', text: /5/, visible: :all, wait: 5)
  end

  it 'passes WCAG 2.1 AA checks' do
    visit better_together.host_jobs_path(locale:)
    expect(page).to have_css('#host-jobs-summary-stats', wait: 10)
    expect(page).to have_css('iframe#host-jobs-sidekiq-iframe', wait: 10)

    expect(page).to be_axe_clean
      .within('#host-jobs-tab')
      .excluding('#host-jobs-sidekiq-iframe')
      .according_to(:wcag2a, :wcag2aa, :wcag21a, :wcag21aa)
  end

  it 'shows the summary panel on the dashboard overview and passes WCAG 2.1 AA checks' do
    visit better_together.host_dashboard_path(locale:)
    expect(page).to have_css('#host-jobs-summary-panel #host-jobs-summary-stats', wait: 10)

    expect(page).to be_axe_clean
      .within('#host-jobs-summary-panel')
      .according_to(:wcag2a, :wcag2aa, :wcag21a, :wcag21aa)
  end
end

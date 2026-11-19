# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Host background jobs', :no_auth do # rubocop:disable RSpec/DescribeClass
  let(:locale) { I18n.default_locale }
  let(:host_platform) { BetterTogether::Platform.find_by(host: true) }
  let(:password) { AutomaticTestConfiguration::DEFAULT_TEST_USER_PASSWORD }

  def snapshot(**overrides)
    BetterTogether::HostJobs::Summary::Snapshot.new(
      available: true, failed: 3, retrying: 2, dead: 1, scheduled: 0, enqueued: 4,
      queues: [BetterTogether::HostJobs::Summary::QueueRow.new(name: 'default', size: 4, latency: 30.0)],
      longest_latency: 30.0, busy: 1, stalled: 0, processes: 1, stalled_after: 10.minutes,
      fetched_at: Time.current, **overrides
    )
  end

  def sign_in_with(permissions, email:, platform: host_platform)
    user = find_or_create_test_user(email, password, :user)
    role = create(:better_together_role, :platform_role, platform:)
    role.assign_resource_permissions(permissions)
    BetterTogether::PersonPlatformMembership.create!(joinable: platform, member: user.person, role:, status: 'active')
    login(email, password)
    user
  end

  def sign_in_steward
    find_or_create_test_user('jobs-steward@example.test', password, :platform_steward)
    login('jobs-steward@example.test', password)
  end

  before do
    configure_host_platform
    Rails.cache.clear
    allow(BetterTogether::HostJobs::Summary).to receive(:call).and_return(snapshot)
  end

  context 'when signed in as a platform steward with manage_platform_jobs' do
    before { sign_in_steward }

    it 'renders the jobs tab with the summary panel and a lazy Sidekiq frame', :aggregate_failures do
      get better_together.host_jobs_path(locale:)

      expect(response).to have_http_status(:ok)
      frame = parsed_response.at_css('turbo-frame#host-jobs-sidekiq')
      expect(frame['src']).to eq(better_together.host_jobs_sidekiq_path(locale:))
      expect(frame['loading']).to eq('lazy')
      expect(parsed_response.at_css('#host-jobs-summary-panel')).to be_present
      expect(parsed_response.at_css('#host-jobs-summary-status[role="status"][aria-live="polite"]')).to be_present
    end

    it 'embeds Sidekiq in a same-origin iframe with the locale and a fallback link', :aggregate_failures do
      get better_together.host_jobs_sidekiq_path(locale: :fr)

      expect(response).to have_http_status(:ok)
      iframe = parsed_response.at_css('turbo-frame#host-jobs-sidekiq iframe#host-jobs-sidekiq-iframe')
      expect(iframe['src']).to eq('/sidekiq/?locale=fr')
      expect(iframe['title']).to eq(I18n.t('host_dashboard.jobs.sidekiq.iframe_title', locale: :fr))
      expect(iframe['loading']).to eq('lazy')
      link = parsed_response.at_css('#host-jobs-sidekiq-open-link')
      expect(link['href']).to eq('/sidekiq/?locale=fr')
      expect(link['target']).to eq('_blank')
    end

    it 'allows its own page to frame same-origin content' do
      get better_together.host_jobs_path(locale:)

      expect(response.headers['Content-Security-Policy']).to include("frame-src 'self'")
    end

    it 'renders the summary counts with links to the Sidekiq pages', :aggregate_failures do
      get better_together.host_jobs_summary_path(locale:, context: 'tab')

      expect(response).to have_http_status(:ok)
      expect(parsed_response.at_css('#host-jobs-failed-count').text.strip).to eq('3')
      expect(parsed_response.at_css('#host-jobs-retrying-link')['href']).to eq('/sidekiq/retries?locale=en')
      expect(parsed_response.at_css('#host-jobs-dead-link')['href']).to eq('/sidekiq/morgue?locale=en')
      expect(parsed_response.at_css('#host-jobs-dead-link')['target']).to eq('host-jobs-sidekiq-iframe')
      expect(parsed_response.at_css('#host-jobs-queue-default')).to be_present
    end

    it 'opens Sidekiq links in the whole window from the overview' do
      get better_together.host_jobs_summary_path(locale:, context: 'overview')

      expect(parsed_response.at_css('#host-jobs-dead-link')['target']).to be_nil
    end

    it 'shows the no-workers alert when no process is running' do
      allow(BetterTogether::HostJobs::Summary).to receive(:call).and_return(snapshot(processes: 0))

      get better_together.host_jobs_summary_path(locale:)

      expect(parsed_response.at_css('#host-jobs-no-processes[role="alert"]')).to be_present
    end

    it 'shows an unavailable state when Redis is down' do
      allow(Sidekiq::Stats).to receive(:new).and_raise(RedisClient::CannotConnectError, 'down')
      allow(BetterTogether::HostJobs::Summary).to receive(:call).and_call_original

      get better_together.host_jobs_summary_path(locale:)

      expect(response).to have_http_status(:ok)
      expect(parsed_response.at_css('#host-jobs-summary-unavailable')).to be_present
    end

    it 'shows the summary panel on the host dashboard overview' do
      get better_together.host_dashboard_path(locale:)

      expect(parsed_response.at_css('#host-jobs-summary-panel #host-jobs-summary-open-tab-link')).to be_present
    end

    it 'serves the Sidekiq UI in a frameable form', :aggregate_failures do
      get '/sidekiq/'

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('/sidekiq/stylesheets/style.css')
      expect(response.headers['X-Frame-Options']).to be_nil
      expect(response.headers['Content-Security-Policy']).not_to include('frame-ancestors')
    end

    it 'renders Sidekiq in the locale passed to it and keeps it for later pages', :aggregate_failures do
      get '/sidekiq/?locale=uk'
      expect(response.headers['content-language']).to eq('uk')

      get '/sidekiq/retries'
      expect(response.headers['content-language']).to eq('uk')
    end

    it 'keeps the steward signed in to the platform after using Sidekiq' do
      get '/sidekiq/?locale=fr'
      get better_together.host_dashboard_path(locale:)

      expect(response).to have_http_status(:ok)
    end
  end

  shared_examples 'no jobs access' do
    it 'does not route the jobs screens', :aggregate_failures do
      %i[host_jobs_path host_jobs_sidekiq_path host_jobs_summary_path].each do |helper|
        get better_together.public_send(helper, locale:)
        expect(response).not_to have_http_status(:ok), helper.to_s
        expect(response.body).not_to include('host-jobs-sidekiq-iframe')
      end
    end

    it 'never serves the Sidekiq UI' do
      get '/sidekiq/'
      follow_redirect! while response.redirect? && response.location.to_s.include?('/sidekiq')

      expect(response.body).not_to include('/sidekiq/stylesheets/style.css')
    end
  end

  context 'when signed in with manage_platform_settings but not manage_platform_jobs' do
    before { sign_in_with(%w[manage_platform_settings], email: 'settings-only@example.test') }

    it_behaves_like 'no jobs access'
  end

  context 'when signed in with manage_platform and manage_platform_settings but not manage_platform_jobs' do
    before { sign_in_with(%w[manage_platform manage_platform_settings], email: 'dashboard-only@example.test') }

    it_behaves_like 'no jobs access'

    it 'leaves the summary panel off the host dashboard', :aggregate_failures do
      get better_together.host_dashboard_path(locale:)

      expect(response).to have_http_status(:ok)
      expect(parsed_response.at_css('#host-jobs-summary-panel')).to be_nil
    end
  end

  context 'when signed in as a steward of another platform' do
    before do
      other = create(:better_together_platform, locality: 'local')
      sign_in_with(%w[manage_platform manage_platform_settings manage_platform_jobs], email: 'other-steward@example.test',
                                                                                      platform: other)
    end

    it_behaves_like 'no jobs access'
  end

  context 'when anonymous' do
    it_behaves_like 'no jobs access'
  end
end

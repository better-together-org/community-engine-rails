# frozen_string_literal: true

require 'rails_helper'

# DOM contract for the background jobs tab, its summary panel and the framed Sidekiq UI. Feature,
# docs screenshot specs and the summary Stimulus controller target these identifiers.
RSpec.describe 'Host background jobs DOM contract', :as_platform_manager, type: :request do # rubocop:disable RSpec/DescribeClass
  let(:locale) { I18n.default_locale }

  def snapshot(**overrides)
    BetterTogether::HostJobs::Summary::Snapshot.new(
      available: true, failed: 3, retrying: 2, dead: 1, scheduled: 4, enqueued: 5,
      queues: [BetterTogether::HostJobs::Summary::QueueRow.new(name: 'mailers', size: 5, latency: 12.0)],
      longest_latency: 12.0, busy: 2, stalled: 1, processes: 1, stalled_after: 10.minutes,
      fetched_at: Time.current, **overrides
    )
  end

  before { allow(BetterTogether::HostJobs::Summary).to receive(:call).and_return(snapshot) }

  it 'renders the jobs tab landmarks, the live region and both frames', :aggregate_failures do
    get better_together.host_jobs_path(locale:)

    %w[#host-jobs-tab #host-jobs-heading #host-jobs-summary-panel #host-jobs-summary-heading
       #host-jobs-sidekiq-section turbo-frame#host-jobs-summary turbo-frame#host-jobs-sidekiq].each do |selector|
      expect(parsed_response.at_css(selector)).to be_present, selector
    end
    status = parsed_response.at_css('#host-jobs-summary-status')
    expect(status.attributes.transform_values(&:value)).to include('role' => 'status', 'aria-live' => 'polite')
    panel = parsed_response.at_css('#host-jobs-summary-panel')
    expect(panel['data-controller']).to eq('better_together--host-jobs-summary')
    expect(panel['data-better_together--host-jobs-summary-interval-value']).to eq('30000')
    expect(parsed_response.at_css('turbo-frame#host-jobs-summary')['data-better_together--host-jobs-summary-target'])
      .to eq('frame')
  end

  it 'renders every summary count, link and the queue table with stable ids', :aggregate_failures do
    get better_together.host_jobs_summary_path(locale:)

    %w[processes busy enqueued stalled failed retrying dead scheduled].each do |key|
      expect(parsed_response.at_css("#host-jobs-stat-#{key} #host-jobs-#{key}-count")).to be_present, key
    end
    %w[failed retrying dead scheduled].each do |key|
      expect(parsed_response.at_css("a#host-jobs-#{key}-link.host-jobs-summary-link")).to be_present, key
    end
    %w[#host-jobs-summary-content #host-jobs-summary-latency #host-jobs-summary-stalled-hint
       #host-jobs-queues-table #host-jobs-queue-mailers #host-jobs-summary-updated].each do |selector|
      expect(parsed_response.at_css(selector)).to be_present, selector
    end
    content = parsed_response.at_css('#host-jobs-summary-content')
    expect(JSON.parse(content['data-host-jobs-summary-counts']))
      .to eq('failed' => 3, 'retrying' => 2, 'dead' => 1, 'stalled' => 1, 'processes' => 1)
    expect(content['data-host-jobs-summary-announcement']).to be_present
  end

  it 'renders the no-workers alert with a stable id' do
    allow(BetterTogether::HostJobs::Summary).to receive(:call).and_return(snapshot(processes: 0))
    get better_together.host_jobs_summary_path(locale:)

    expect(parsed_response.at_css('#host-jobs-no-processes')).to be_present
  end

  it 'renders the unavailable state with a stable id' do
    allow(BetterTogether::HostJobs::Summary).to receive(:call).and_return(snapshot(available: false))
    get better_together.host_jobs_summary_path(locale:)

    expect(response.body).to include('id="host-jobs-summary-unavailable"')
  end

  it 'renders the Sidekiq embed, its iframe and the fallback link', :aggregate_failures do
    get better_together.host_jobs_sidekiq_path(locale:)

    %w[#host-jobs-sidekiq-embed iframe#host-jobs-sidekiq-iframe[name="host-jobs-sidekiq-iframe"]
       a#host-jobs-sidekiq-open-link].each do |selector|
      expect(parsed_response.at_css(selector)).to be_present, selector
    end
  end
end

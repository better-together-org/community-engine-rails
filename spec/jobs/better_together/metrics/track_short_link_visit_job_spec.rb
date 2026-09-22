# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Metrics::TrackShortLinkVisitJob do
  subject(:job) { described_class.new }

  let(:short_link) { create(:better_together_short_link) }
  let(:platform)   { create(:better_together_platform) }

  def base_payload(overrides = {})
    {
      'short_link_id' => short_link.id,
      'platform_id' => platform.id,
      'referrer' => 'https://example.com',
      'user_agent' => 'Mozilla/5.0 (X11; Linux x86_64)',
      'remote_addr' => '127.0.0.1',
      'logged_in' => false,
      'visited_at' => Time.current.iso8601
    }.merge(overrides)
  end

  describe '#perform' do
    it 'creates a ShortLinkVisit record' do
      expect { job.perform(base_payload) }
        .to change(BetterTogether::Metrics::ShortLinkVisit, :count).by(1)
    end

    it 'stores the referrer, user_agent, and logged_in flag' do
      job.perform(base_payload)
      visit = BetterTogether::Metrics::ShortLinkVisit.last
      expect(visit.referrer).to eq('https://example.com')
      expect(visit.logged_in).to be false
    end

    it 'truncates referrer to 2048 characters' do
      long_referrer = 'x' * 3000
      job.perform(base_payload('referrer' => long_referrer))
      expect(BetterTogether::Metrics::ShortLinkVisit.last.referrer.length).to be <= 2048
    end

    it 'marks known bot user agents as potential_bot: true' do
      job.perform(base_payload('user_agent' => 'Googlebot/2.1'))
      expect(BetterTogether::Metrics::ShortLinkVisit.last.potential_bot).to be true
    end

    it 'does not flag a normal browser as a bot' do
      job.perform(base_payload('user_agent' => 'Mozilla/5.0 (Windows NT 10.0)'))
      expect(BetterTogether::Metrics::ShortLinkVisit.last.potential_bot).to be false
    end

    it 'sets potential_bot: false when user_agent is blank' do
      job.perform(base_payload('user_agent' => ''))
      expect(BetterTogether::Metrics::ShortLinkVisit.last.potential_bot).to be false
    end
  end
end

# frozen_string_literal: true

require 'rails_helper'

module BetterTogether # :nodoc:
  RSpec.describe Metrics::TrackSearchQueryJob do
    let(:host_platform) { BetterTogether::Platform.find_by(host: true) || create(:better_together_platform, :host) }

    subject(:perform_job) { described_class.perform_now('foo', 2, 'en', host_platform.id, true) }

    it 'creates a search query metric' do
      expect { perform_job }.to change(Metrics::SearchQuery, :count).by(1)
    end

    it 'stores provided attributes' do
      perform_job
      metric = Metrics::SearchQuery.last
      expect(metric).to have_attributes(
        query: 'foo',
        results_count: 2,
        locale: 'en',
        platform_id: host_platform.id,
        logged_in: true
      )
    end
  end
end

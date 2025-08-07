# frozen_string_literal: true

require 'rails_helper'

module BetterTogether
  RSpec.describe Metrics::TrackSearchQueryJob, type: :job do
    subject(:perform_job) { described_class.perform_now('foo', 2, 'en') }

    it 'creates a search query metric' do
      expect { perform_job }.to change(Metrics::SearchQuery, :count).by(1)
    end

    it 'stores provided attributes' do
      perform_job
      metric = Metrics::SearchQuery.last
      expect(metric).to have_attributes(query: 'foo', results_count: 2, locale: 'en')
    end
  end
end

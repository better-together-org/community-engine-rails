# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Metrics::SharesController do # rubocop:todo RSpec/SpecFilePathFormat
  include ActiveJob::TestHelper

  let(:page) { create(:page) }
  let(:url) { 'https://example.org/somewhere' }

  # rubocop:todo RSpec/MultipleExpectations
  it 'creates a share for an allowed shareable type' do # rubocop:todo RSpec/MultipleExpectations
    # rubocop:enable RSpec/MultipleExpectations
    perform_enqueued_jobs do
      expect do
        post better_together.metrics_shares_path(locale: I18n.default_locale), params: {
          platform: 'facebook',
          url: url,
          shareable_type: 'BetterTogether::Page',
          shareable_id: page.id
        }
      end.to change(BetterTogether::Metrics::Share, :count).by(1)
    end

    share = BetterTogether::Metrics::Share.last
    expect(share.shareable).to eq(page)
  end

  it 'rejects disallowed shareable types via resolver (no record created)' do
    perform_enqueued_jobs do
      expect do
        post better_together.metrics_shares_path(locale: I18n.default_locale), params: {
          platform: 'facebook',
          url: url,
          shareable_type: 'Kernel',
          shareable_id: page.id
        }
      end.not_to change(BetterTogether::Metrics::Share, :count)
    end
  end
end

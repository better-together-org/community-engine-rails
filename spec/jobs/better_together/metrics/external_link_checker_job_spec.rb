# frozen_string_literal: true

require 'rails_helper'
require 'webmock/rspec'

module BetterTogether
  RSpec.describe Metrics::ExternalLinkCheckerJob, type: :job do
    let(:link) { BetterTogether::Content::Link.create!(url: 'https://external.test/', valid_link: false) }

    it 'updates link status on success' do
      stub_request(:head, 'https://external.test/').to_return(status: 200)

      described_class.new.perform(link.id)

      link.reload
      expect(link.valid_link).to be true
      expect(link.latest_status_code).to eq('200')
    end
  end
end

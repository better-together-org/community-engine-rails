# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Metrics::LinkCheckerReport, 'platform scoping' do # rubocop:disable RSpec/DescribeMethod
  describe '.create_and_generate!' do
    it 'accepts and persists an explicit creator and platform' do
      federated_platform = create(:better_together_platform, :public, host: false)
      creator = create(:better_together_person)

      report = described_class.create_and_generate!(creator: creator, platform: federated_platform)

      expect(report.creator).to eq(creator)
      expect(report.platform).to eq(federated_platform)
    end

    it 'falls back to the host platform when no platform is given (e.g. scheduled job)' do
      host_platform = BetterTogether::Platform.find_by(host: true) || create(:better_together_platform, :host)

      report = described_class.create_and_generate!

      expect(report.platform).to eq(host_platform)
      expect(report.creator).to be_nil
    end
  end
end

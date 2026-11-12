# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Billing::HostedAccount do
  let(:hosted) { create(:better_together_platform) }

  it 'is valid active, once per platform' do
    described_class.create!(platform: hosted)

    expect(described_class.new(platform: hosted)).not_to be_valid
  end

  it 'needs a reason to be suspended' do
    expect(described_class.new(platform: hosted, status: 'suspended')).not_to be_valid
  end

  it 'cannot belong to the host platform' do
    host = BetterTogether::Platform.find_by(host: true) || create(:better_together_platform, :host)

    expect(described_class.new(platform: host)).not_to be_valid
  end
end

# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Joatu::ConnectionRequestPolicy, type: :policy do
  let(:normal_user) { create(:better_together_user) }
  let(:request_record) { create(:better_together_joatu_connection_request) }

  it 'is a subclass of BetterTogether::Joatu::RequestPolicy' do
    expect(described_class.ancestors).to include(BetterTogether::Joatu::RequestPolicy)
  end

  describe '#show?' do
    it 'denies guests for connection requests (authentication-gated)' do
      expect(described_class.new(nil, request_record).show?).to be false
    end
  end

  describe '#create?' do
    it 'denies guests' do
      expect(described_class.new(nil, request_record).create?).to be false
    end
  end
end

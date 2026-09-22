# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::MessageRequestPolicy do
  subject(:policy) { described_class.new(sender_user, message_request) }

  let(:platform) { message_request.platform }
  let(:message_request) { create(:better_together_message_request) }
  let(:sender) { message_request.sender }
  let(:recipient) { message_request.recipient }
  let!(:sender_user) { create(:better_together_user, :confirmed, person: sender) }
  let!(:recipient_user) { create(:better_together_user, :confirmed, person: recipient) }

  around do |example|
    Current.platform = platform
    example.run
    Current.platform = nil
  end

  before do
    # message_requests defaults to alpha rollout (config/feature_gates.yml) — set the
    # platform's override to stable so these "allowed" specs aren't testing rollout
    # access resolution (that's covered separately below and in platform_feature_gate_spec.rb).
    platform.update!(feature_gate_rollouts: { 'message_requests' => 'stable' })
  end

  it 'allows the sender to create and show the request' do
    expect(policy.create?).to be(true)
    expect(policy.show?).to be(true)
  end

  it 'allows the recipient to show, accept, and decline the request, but not to accept as the sender' do
    recipient_policy = described_class.new(recipient_user, message_request)

    expect(recipient_policy.show?).to be(true)
    expect(recipient_policy.accept?).to be(true)
    expect(recipient_policy.decline?).to be(true)
    expect(policy.accept?).to be(false)
  end

  context 'when the message_requests feature rollout is off' do
    before { platform.update!(feature_gate_rollouts: { 'message_requests' => 'off' }) }

    it 'denies index, create, show, and accept regardless of participation' do
      recipient_policy = described_class.new(recipient_user, message_request)

      expect(policy.index?).to be(false)
      expect(policy.create?).to be(false)
      expect(policy.show?).to be(false)
      expect(recipient_policy.accept?).to be(false)
    end
  end

  describe 'Scope' do
    it 'scopes to requests where the actor participates' do
      other_request = create(:better_together_message_request, platform:)

      resolved = described_class::Scope.new(sender_user, BetterTogether::MessageRequest.all).resolve

      expect(resolved).to include(message_request)
      expect(resolved).not_to include(other_request)
    end

    it 'returns no requests when the feature rollout is disabled' do
      platform.update!(feature_gate_rollouts: { 'message_requests' => 'off' })

      resolved = described_class::Scope.new(sender_user, BetterTogether::MessageRequest.all).resolve

      expect(resolved).to be_empty
    end
  end
end

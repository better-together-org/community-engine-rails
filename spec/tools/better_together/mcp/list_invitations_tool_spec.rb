# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Mcp::ListInvitationsTool, type: :model do
  let(:user) { create(:user) }
  let(:person) { user.person }
  let!(:own_invitation) { create(:better_together_invitation, inviter: person) }
  let!(:other_invitation) { create(:better_together_invitation) }

  before do
    configure_host_platform
    stub_mcp_request_for(described_class, user: user)
  end

  describe '.description' do
    it 'has a helpful description' do
      expect(described_class.description).to include('invitation')
    end
  end

  describe '#call' do
    it 'returns invitations for the current user' do
      tool = described_class.new
      result = JSON.parse(tool.call)

      ids = result.map { |i| i['id'] }
      expect(ids).to include(own_invitation.id)
      expect(ids).not_to include(other_invitation.id)
    end

    it 'returns invitation attributes' do
      tool = described_class.new
      result = JSON.parse(tool.call)

      next if result.empty?

      invitation = result.first
      expect(invitation).to have_key('id')
      expect(invitation).to have_key('status')
      expect(invitation).to have_key('invitee_email')
      expect(invitation).to have_key('inviter_name')
    end

    it 'filters by status when provided' do
      create(:better_together_invitation, :accepted, inviter: person)
      tool = described_class.new
      result = JSON.parse(tool.call(status_filter: 'pending'))

      statuses = result.map { |i| i['status'] }
      expect(statuses).to all(eq('pending'))
    end

    it 'respects limit parameter' do
      3.times { create(:better_together_invitation, inviter: person) }
      tool = described_class.new
      result = JSON.parse(tool.call(limit: 2))

      expect(result.length).to be <= 2
    end

    context 'when not authenticated' do
      before { stub_mcp_request_for(described_class, user: nil) }

      it 'returns error message' do
        tool = described_class.new
        result = JSON.parse(tool.call)

        expect(result).to have_key('error')
      end
    end
  end
end

# frozen_string_literal: true

require 'rails_helper'

# Someone buying in person who is not on the platform yet: made from a name and an email, never duplicated.
RSpec.describe BetterTogether::Billing::OfflinePayments::NewBuyer do
  let(:platform) { configure_host_platform }
  let(:steward) { create(:better_together_person) }

  before do
    { 'platform_member' => :platform_role, 'community_member' => :community_role }.each do |id, kind|
      create(:better_together_role, kind, identifier: id) unless BetterTogether::Role.exists?(identifier: id)
    end
  end

  def call(**) = described_class.call(platform:, inviter: steward, name: 'Odalys Fortier', email: 'Odalys@Example.test', **)

  it 'makes a person with that email as their primary one, a platform member, and a pending community invitation' do
    result = call

    expect(result.person).to have_attributes(name: 'Odalys Fortier', email: 'odalys@example.test')
    expect(BetterTogether::PersonPlatformMembership.active.where(joinable: platform, member: result.person)).to exist
    expect(result.invitation).to have_attributes(invitee: result.person, inviter: steward, invitee_email: 'odalys@example.test',
                                                 status: 'pending')
  end

  it 'finds the person an email already belongs to, and invites no one' do
    first = call.person

    again = call

    expect(again.person).to eq(first)
    expect(again.invitation).to be_nil
  end

  it 'refuses a missing name or an email that is not one' do
    expect { call(name: '') }.to raise_error(described_class::Invalid)
    expect { call(email: 'not-an-email') }.to raise_error(described_class::Invalid)
  end
end

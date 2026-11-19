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

  it 'refuses an email that belongs to a member of this platform, and makes no one' do
    member = call.person

    expect { expect { call }.to raise_error(described_class::MemberEmail) }.not_to change(BetterTogether::Person, :count)
    expect(member.reload.email).to eq('odalys@example.test')
  end

  context 'when the email belongs to an account that is not a member of this platform' do
    let!(:account) { create(:better_together_user, email: 'odalys@example.test').person }

    it 'makes a guest with no login and no email, never the account, and invites no one' do
      result = call

      expect(result.person).not_to eq(account)
      expect(result.person).to have_attributes(name: 'Odalys Fortier', platform_id: platform.id, user: nil)
      expect(result.person.email_addresses).to be_empty
      expect(result.invitation).to be_nil
      expect(BetterTogether::PersonPlatformMembership.where(member: result.person)).to be_empty
    end

    it 'leaves the account as it was' do
      expect { call }.not_to(change { [account.reload.updated_at, account.person_platform_memberships.count, account.email_addresses.count] })
    end
  end

  context 'with the daily cap on invitations' do
    before { allow(BetterTogether::Billing::Configuration).to receive(:walk_up_invitation_cap).and_return(2) }

    it 'refuses a new email once the steward has invited the cap in the last day' do
      2.times { |i| call(email: "new#{i}@example.test") }

      expect { call(email: 'new9@example.test') }.to raise_error(described_class::OverCap)
    end

    it 'refuses an email of a non-member account the same way, so the refusal does not tell them apart' do
      create(:better_together_user, email: 'known@example.test')
      2.times { |i| call(email: "new#{i}@example.test") }

      expect { call(email: 'known@example.test') }.to raise_error(described_class::OverCap)
    end

    it 'counts only this steward and only the last day' do
      2.times { |i| call(email: "new#{i}@example.test") }
      BetterTogether::CommunityInvitation.update_all(created_at: 2.days.ago) # rubocop:disable Rails/SkipsModelValidations

      expect { call(email: 'later@example.test') }.not_to raise_error
      expect { described_class.call(platform:, inviter: create(:better_together_person), name: 'X Y', email: 'other@example.test') }
        .not_to raise_error
    end
  end

  it 'refuses a missing name or an email that is not one' do
    expect { call(name: '') }.to raise_error(described_class::Invalid)
    expect { call(email: 'not-an-email') }.to raise_error(described_class::Invalid)
  end
end

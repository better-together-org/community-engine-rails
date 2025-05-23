# frozen_string_literal: true

# spec/models/better_together/platform_invitation_spec.rb

require 'rails_helper'

module BetterTogether # rubocop:todo Metrics/ModuleLength
  RSpec.describe PlatformInvitation, type: :model do # rubocop:todo Metrics/BlockLength
    subject(:platform_invitation) { build(:better_together_platform_invitation) }

    describe 'Factory' do
      it 'has a valid factory' do
        expect(platform_invitation).to be_valid
      end
    end

    describe 'ActiveRecord associations' do
      it { is_expected.to belong_to(:invitable).class_name('BetterTogether::Platform') }
      it { is_expected.to belong_to(:inviter).class_name('BetterTogether::Person') }
      it { is_expected.to belong_to(:invitee).class_name('BetterTogether::Person').optional }
      it { is_expected.to belong_to(:community_role).class_name('BetterTogether::Role') }
      it { is_expected.to belong_to(:platform_role).class_name('BetterTogether::Role') }
    end

    describe 'ActiveModel validations' do
      it {
        is_expected.to validate_uniqueness_of(:invitee_email).scoped_to(:invitable_id)
                                                             .allow_nil.allow_blank.case_insensitive
      }
      it { is_expected.to validate_presence_of(:locale) }
      it { is_expected.to validate_inclusion_of(:locale).in_array(I18n.available_locales.map(&:to_s)) }
      it { is_expected.to validate_presence_of(:status) }
      it { is_expected.to validate_uniqueness_of(:token) }

      context 'status transitions' do
        it 'allows valid transitions' do
          platform_invitation.status = 'pending'
          platform_invitation.save!

          platform_invitation.status = 'accepted'
          expect(platform_invitation).to be_valid
          expect(platform_invitation.accepted_at).not_to be_nil
        end

        it 'prevents invalid transitions' do
          platform_invitation.status = 'accepted'
          platform_invitation.save!

          platform_invitation.status = 'pending'
          expect(platform_invitation).not_to be_valid
          expect(platform_invitation.errors[:status]).to include('cannot transition from accepted to pending')
        end
      end
    end

    describe 'Attributes' do
      it { is_expected.to respond_to(:invitee_email) }
      it { is_expected.to respond_to(:status) }
      it { is_expected.to respond_to(:locale) }
      it { is_expected.to respond_to(:token) }
      it { is_expected.to respond_to(:valid_from) }
      it { is_expected.to respond_to(:valid_until) }
      it { is_expected.to respond_to(:last_sent) }
      it { is_expected.to respond_to(:accepted_at) }
    end

    describe 'Scopes' do
      describe '.pending' do
        it 'returns only pending invitations' do
          pending_invitation = create(:better_together_platform_invitation, status: 'pending')
          create(:better_together_platform_invitation, status: 'accepted')

          expect(BetterTogether::PlatformInvitation.pending).to include(pending_invitation)
          expect(BetterTogether::PlatformInvitation.pending.count).to eq(1)
        end
      end

      describe '.accepted' do
        it 'returns only accepted invitations' do
          accepted_invitation = create(:better_together_platform_invitation, status: 'accepted')
          create(:better_together_platform_invitation, status: 'pending')

          expect(BetterTogether::PlatformInvitation.accepted).to include(accepted_invitation)
          expect(BetterTogether::PlatformInvitation.accepted.count).to eq(1)
        end
      end

      describe '.expired' do
        it 'returns only expired invitations' do
          expired_invitation = create(:better_together_platform_invitation, valid_until: 1.day.ago)
          create(:better_together_platform_invitation, valid_until: 1.day.from_now)

          expect(BetterTogether::PlatformInvitation.expired).to include(expired_invitation)
          expect(BetterTogether::PlatformInvitation.expired.count).to eq(1)
        end
      end
    end

    describe 'Methods' do
      describe '#expired?' do
        context 'when valid_until is in the past' do
          before { platform_invitation.valid_until = 1.day.ago }

          it 'returns true' do
            expect(platform_invitation.expired?).to be true
          end
        end

        context 'when valid_until is in the future' do
          before { platform_invitation.valid_until = 1.day.from_now }

          it 'returns false' do
            expect(platform_invitation.expired?).to be false
          end
        end

        context 'when valid_until is nil' do
          before { platform_invitation.valid_until = nil }

          it 'returns false' do
            expect(platform_invitation.expired?).to be false
          end
        end
      end
    end

    describe 'Throttle and Recent Email Checks' do # rubocop:todo Metrics/BlockLength
      describe '#email_recently_sent?' do
        context 'when last_sent is within the last 15 minutes' do
          before { platform_invitation.last_sent = 10.minutes.ago }

          it 'returns true' do
            expect(platform_invitation.send(:email_recently_sent?)).to be true
          end
        end

        context 'when last_sent is older than 15 minutes' do
          before { platform_invitation.last_sent = 20.minutes.ago }

          it 'returns false' do
            expect(platform_invitation.send(:email_recently_sent?)).to be false
          end
        end
      end

      describe '#throttled?' do
        context 'when more than 10 invitations have been created in the last 15 minutes by the same inviter' do
          let(:inviter) { create(:person) }

          before do
            create_list(:better_together_platform_invitation, 11, inviter:, created_at: 10.minutes.ago)
            platform_invitation.inviter = inviter
          end

          it 'returns true' do
            expect(platform_invitation.send(:throttled?)).to be true
          end
        end

        context 'when 10 or fewer invitations have been created in the last 15 minutes by the same inviter' do
          let(:inviter) { create(:person) }

          before do
            create_list(:better_together_platform_invitation, 10, inviter:, created_at: 10.minutes.ago)
            platform_invitation.inviter = inviter
          end

          it 'returns false' do
            expect(platform_invitation.send(:throttled?)).to be false
          end
        end
      end
    end
  end
end

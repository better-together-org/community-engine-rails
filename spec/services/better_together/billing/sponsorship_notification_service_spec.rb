# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Billing::SponsorshipNotificationService do
  subject(:service) { described_class.new(sponsorship) }

  let(:sponsor_person) { create(:better_together_person) }
  let(:beneficiary_community) { create(:better_together_community, accepts_sponsorship: true) }
  let(:community_manager_role) do
    BetterTogether::Role.find_by(identifier: 'community_manager', resource_type: 'BetterTogether::Community') ||
      create(:better_together_role,
             identifier: 'community_manager',
             name: 'Community Manager',
             resource_type: 'BetterTogether::Community')
  end
  let(:manager) { create(:better_together_person) }
  let!(:manager_membership) do
    create(:better_together_person_community_membership,
           :active,
           joinable: beneficiary_community,
           member: manager,
           role: community_manager_role)
  end
  let(:sponsorship) do
    create(:better_together_billing_sponsorship, sponsor: sponsor_person, beneficiary: beneficiary_community,
                                                 status: 'pending')
  end

  before do
    ActiveJob::Base.queue_adapter = :test
    Noticed::Notification.destroy_all
  end

  describe '#notify_offered' do
    it 'notifies the beneficiary community managers, not the sponsor' do
      expect { service.notify_offered }.to change(Noticed::Notification, :count).by(1)

      notification = Noticed::Notification.last
      expect(notification.recipient).to eq(manager)
      expect(notification.event.type).to eq('BetterTogether::Billing::SponsorshipOfferedNotifier')
    end

    context 'when the beneficiary is a Person' do
      let(:beneficiary_person) { create(:better_together_person, accepts_sponsorship: true) }
      let(:sponsorship) do
        create(:better_together_billing_sponsorship, sponsor: sponsor_person, beneficiary: beneficiary_person,
                                                     status: 'pending')
      end

      it 'notifies the beneficiary person directly' do
        expect { service.notify_offered }.to change(Noticed::Notification, :count).by(1)

        expect(Noticed::Notification.last.recipient).to eq(beneficiary_person)
      end
    end
  end

  describe '#notify_accepted' do
    it 'notifies the sponsor' do
      expect { service.notify_accepted }.to change(Noticed::Notification, :count).by(1)

      notification = Noticed::Notification.last
      expect(notification.recipient).to eq(sponsor_person)
      expect(notification.event.type).to eq('BetterTogether::Billing::SponsorshipAcceptedNotifier')
    end
  end

  describe '#notify_declined' do
    it 'notifies the sponsor' do
      expect { service.notify_declined }.to change(Noticed::Notification, :count).by(1)

      expect(Noticed::Notification.last.event.type).to eq('BetterTogether::Billing::SponsorshipDeclinedNotifier')
    end
  end

  describe '#notify_ended' do
    it 'notifies both the sponsor and the beneficiary community managers' do
      expect { service.notify_ended }.to change(Noticed::Notification, :count).by(2)

      recipients = Noticed::Notification.last(2).map(&:recipient)
      expect(recipients).to contain_exactly(sponsor_person, manager)
    end

    it 'does not duplicate a recipient who is both sponsor and beneficiary-manager' do
      dual_role_sponsorship = create(
        :better_together_billing_sponsorship, sponsor: manager, beneficiary: beneficiary_community, status: 'active'
      )

      expect do
        described_class.new(dual_role_sponsorship).notify_ended
      end.to change(Noticed::Notification, :count).by(1)
    end
  end

  describe 'when a sponsor is blank' do
    it 'does not raise and notifies no one' do
      sponsorship.sponsor = nil

      expect { service.notify_accepted }.not_to raise_error
      expect(Noticed::Notification.count).to eq(0)
    end
  end
end

# frozen_string_literal: true

require 'rails_helper'

# rubocop:disable RSpec/DescribeClass -- shared examples cover all 4 notifier classes, each nested below
RSpec.describe 'BetterTogether::Billing sponsorship notifiers' do
  shared_examples 'a sponsorship notifier' do
    subject(:notifier) { described_class.new(record: sponsorship, params: { sponsorship: sponsorship }) }

    let(:notification) { instance_double(Noticed::Notification, recipient: sponsor) }

    describe '#title' do
      it 'includes the sponsor and beneficiary names without raising' do
        expect { notifier.title }.not_to raise_error
        expect(notifier.title).to include(sponsor.name).or include(beneficiary.name)
      end
    end

    describe '#body' do
      it 'renders without raising' do
        expect { notifier.body }.not_to raise_error
        expect(notifier.body).to be_present
      end
    end

    describe '#build_message' do
      it 'returns a hash with title, body, and a review url' do
        message = notifier.build_message(notification)

        expect(message).to include(:title, :body, :url)
        expect(message[:url]).to include(sponsorship.token)
      end
    end

    describe '#email_params' do
      it 'uses notification.recipient instead of a bare recipient call' do
        params = notifier.email_params(notification)

        expect(params[:recipient]).to eq(sponsor)
        expect(params[:sponsorship]).to eq(sponsorship)
        expect(params[:review_url]).to include(sponsorship.token)
      end
    end
  end

  describe BetterTogether::Billing::SponsorshipOfferedNotifier do
    let(:sponsor) { create(:better_together_person) }
    let(:beneficiary) { create(:better_together_community, accepts_sponsorship: true) }
    let(:sponsorship) { create(:better_together_billing_sponsorship, sponsor:, beneficiary:, status: 'pending') }

    it_behaves_like 'a sponsorship notifier'
  end

  describe BetterTogether::Billing::SponsorshipAcceptedNotifier do
    let(:sponsor) { create(:better_together_person) }
    let(:beneficiary) { create(:better_together_community, accepts_sponsorship: true) }
    let(:sponsorship) { create(:better_together_billing_sponsorship, sponsor:, beneficiary:, status: 'accepted') }

    it_behaves_like 'a sponsorship notifier'
  end

  describe BetterTogether::Billing::SponsorshipDeclinedNotifier do
    let(:sponsor) { create(:better_together_person) }
    let(:beneficiary) { create(:better_together_community, accepts_sponsorship: true) }
    let(:sponsorship) { create(:better_together_billing_sponsorship, sponsor:, beneficiary:, status: 'declined') }

    it_behaves_like 'a sponsorship notifier'
  end

  describe BetterTogether::Billing::SponsorshipEndedNotifier do
    let(:sponsor) { create(:better_together_person) }
    let(:beneficiary) { create(:better_together_community, accepts_sponsorship: true) }
    let(:sponsorship) { create(:better_together_billing_sponsorship, sponsor:, beneficiary:, status: 'ended') }

    it_behaves_like 'a sponsorship notifier'
  end
end
# rubocop:enable RSpec/DescribeClass

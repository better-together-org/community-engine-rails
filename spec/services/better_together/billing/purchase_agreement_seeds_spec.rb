# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Billing::PurchaseAgreementSeeds do
  include_context 'with clean billing processors'
  include_context 'with builtin billing processors'

  let!(:host_platform) { configure_host_platform }
  let(:other_platform) { create(:better_together_platform) }

  it 'seeds the three purchase agreements as drafts with placeholder text, so nothing can be sold by accident' do
    agreements = described_class.call(host_platform)

    expect(agreements.keys).to contain_exactly('subscription_agreement', 'one_time_purchase_agreement', 'offline_payment_terms')
    agreements.each_value do |agreement|
      expect(agreement).to have_attributes(lifecycle_state: 'draft', agreement_kind: 'transactional_agreement', protected: true,
                                           requires_reacceptance: true, required_for: 'none', platform_id: host_platform.id)
      expect(agreement.change_summary).to eq(described_class::PLACEHOLDER)
      expect(agreement.agreement_terms.first.content.to_plain_text).to include('placeholder')
    end
  end

  it 'ties them to the purchases they cover' do
    described_class.call(host_platform)
    rows = host_platform.billing_agreement_requirements.includes(:agreement).map { |r| [r.agreement.identifier, r.purpose, r.payment_method] }

    expect(rows).to contain_exactly(
      ['subscription_agreement', 'subscription', nil], ['one_time_purchase_agreement', 'one_time', nil],
      ['one_time_purchase_agreement', 'ticket', nil], ['one_time_purchase_agreement', 'exchange', nil],
      ['offline_payment_terms', nil, 'cash'], ['offline_payment_terms', nil, 'cheque'], ['offline_payment_terms', nil, 'etransfer']
    )
  end

  it 'can be run again without duplicating or overwriting what a steward changed' do
    first = described_class.call(host_platform)
    steward_edit = first['subscription_agreement']
    steward_edit.update!(lifecycle_state: 'active', title: 'Our subscription terms')
    steward_edit.agreement_terms.first.update!(content: 'Our own words')

    expect { described_class.call(host_platform) }.not_to(change do
      [BetterTogether::Agreement.count, BetterTogether::AgreementTerm.count, host_platform.billing_agreement_requirements.count]
    end)
    expect(steward_edit.reload).to have_attributes(lifecycle_state: 'active')
    expect(steward_edit.title).to eq('Our subscription terms')
    expect(steward_edit.agreement_terms.first.content.to_plain_text).to eq('Our own words')
  end

  it 'gives each platform its own copies, so one platform\'s terms never apply to another' do
    mine = described_class.call(host_platform)
    theirs = described_class.call(other_platform)

    expect(mine['subscription_agreement']).not_to eq(theirs['subscription_agreement'])
    expect(theirs['subscription_agreement'].platform_id).to eq(other_platform.id)
    expect(other_platform.billing_agreement_requirements.count).to eq(7)
    expect(BetterTogether::Agreement.billing_record('subscription_agreement', platform: other_platform)).to eq(theirs['subscription_agreement'])
  end

  it 'is called by the agreement builder for the host platform' do
    BetterTogether::AgreementBuilder.build_purchase_agreements

    expect(BetterTogether::Agreement.billing_record('one_time_purchase_agreement', platform: host_platform)).to be_present
  end
end

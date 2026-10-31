# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Billing::OrderAgreementAcceptance do
  include_context 'with orders fixtures'

  let(:order) { place_order }
  let(:agreement) { order.agreement_acceptances.first.agreement }

  def evidence(**overrides)
    { platform_id: host_platform.id, agreement:, signer: buyer, agreement_identifier: 'x', agreement_title: 'x', agreement_content_digest: 'x',
      acceptance_method: 'checkout', accepted_at: Time.current }.merge(overrides)
  end

  it 'is recorded for each agreement when an order is placed, as the signer accepted it' do
    acceptance = order.agreement_acceptances.first

    expect(acceptance).to have_attributes(platform_id: host_platform.id, signer: buyer, agreement_identifier: 'one_time_purchase_agreement',
                                          acceptance_method: 'checkout')
    expect(acceptance.agreement_title).to eq(agreement.title)
    expect(acceptance.agreement_content_digest).to be_present
    expect(acceptance.accepted_at).to be_present
  end

  it 'keeps what applied to this purchase when the agreement changes or is accepted again later' do
    acceptance = order.agreement_acceptances.first
    digest = acceptance.agreement_content_digest

    agreement.update!(title: 'A completely new title', change_summary: 'New terms')
    BetterTogether::AgreementAcceptanceRecorder.record!(agreement:, participant: buyer, acceptance_method: 'agreement_review')

    expect(acceptance.reload).to have_attributes(agreement_content_digest: digest, acceptance_method: 'checkout')
    expect(acceptance.agreement_title).not_to eq('A completely new title')
  end

  it 'is never rewritten' do
    acceptance = order.agreement_acceptances.first

    expect { acceptance.update!(agreement_title: 'Edited') }.to raise_error(ActiveRecord::ReadOnlyRecord)
  end

  it 'is recorded once per agreement and order' do
    duplicate = order.agreement_acceptances.build(evidence)

    expect(duplicate).not_to be_valid
    expect { duplicate.save!(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
  end

  it 'cannot be recorded for someone who did not accept' do
    stranger = create(:better_together_person)

    expect { described_class.record!(order:, agreement:, signer: stranger) }.to raise_error(ArgumentError, /not accepted/)
  end

  it 'takes only a known acceptance method' do
    built = order.agreement_acceptances.build(evidence(acceptance_method: 'carrier_pigeon'))

    expect(built).not_to be_valid
  end

  it 'takes its platform from its order and is tied to it at the database level' do
    other = create(:better_together_platform)
    another = create(:better_together_agreement, agreement_kind: 'transactional_agreement', platform: host_platform, identifier: 'another-terms')

    expect do
      order.agreement_acceptances.build(evidence(platform_id: other.id, agreement: another)).save!(validate: false)
    end.to raise_error(ActiveRecord::InvalidForeignKey)
  end

  it 'refuses an on-behalf-of owner type that is not allowed' do
    built = order.agreement_acceptances.build(evidence)
    built.assign_attributes(on_behalf_of_type: 'Kernel', on_behalf_of_id: SecureRandom.uuid)

    expect(built).not_to be_valid
  end

  it 'accepts the two new ways an agreement can be accepted' do
    expect(BetterTogether::AgreementParticipant.acceptance_methods.keys).to include('checkout', 'seller_assisted')
  end
end

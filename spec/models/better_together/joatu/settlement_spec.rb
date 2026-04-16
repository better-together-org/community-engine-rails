# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Joatu::Settlement do
  let(:payer)     { create(:better_together_person) }
  let(:recipient) { create(:better_together_person) }
  let(:offer)     { create(:better_together_joatu_offer,   creator: recipient) }
  let(:request)   { create(:better_together_joatu_request, creator: payer) }
  let(:agreement) { create(:better_together_joatu_agreement, offer:, request:) }

  let(:payer_balance) do
    BetterTogether::C3::Balance.find_or_create_by!(holder: payer).tap do |b|
      b.credit!(5.0) # 5 C3 = 50_000 millitokens
    end
  end
  let(:recipient_balance) do
    BetterTogether::C3::Balance.find_or_create_by!(holder: recipient)
  end

  let(:lock_ref) do
    payer_balance.lock!(2.0, agreement_ref: agreement.identifier)
  end

  let(:settlement) do
    described_class.create!(
      agreement: agreement,
      payer: payer,
      recipient: recipient,
      c3_millitokens: 20_000,
      lock_ref: lock_ref,
      status: 'pending'
    )
  end

  describe 'validations' do
    it 'is valid with valid attributes' do
      expect(settlement).to be_valid
    end

    it 'rejects an unknown status' do
      s = described_class.new(
        agreement: agreement, payer: payer, recipient: recipient,
        c3_millitokens: 1000, status: 'bogus'
      )
      expect(s).not_to be_valid
      expect(s.errors[:status]).to be_present
    end

    it 'rejects negative millitokens' do
      s = described_class.new(
        agreement: agreement, payer: payer, recipient: recipient,
        c3_millitokens: -1, status: 'pending'
      )
      expect(s).not_to be_valid
    end

    it 'rejects millitokens above MAX_SINGLE_TRANSACTION_MILLITOKENS' do
      s = described_class.new(
        agreement: agreement, payer: payer, recipient: recipient,
        c3_millitokens: BetterTogether::C3::Token::MAX_SINGLE_TRANSACTION_MILLITOKENS + 1,
        status: 'pending'
      )
      expect(s).not_to be_valid
    end

    it 'enforces uniqueness per agreement (one settlement per agreement)' do
      settlement # create first
      duplicate = described_class.new(
        agreement: agreement, payer: payer, recipient: recipient,
        c3_millitokens: 5000, status: 'pending'
      )
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:agreement_id]).to be_present
    end
  end

  describe '#c3_amount' do
    it 'converts millitokens to C3 float' do
      expect(settlement.c3_amount).to eq(2.0)
    end
  end

  describe '#complete!' do
    it 'transfers C3 from payer to recipient and mints a token' do
      expect do
        settlement.complete!(payer_balance: payer_balance.reload, recipient_balance: recipient_balance.reload)
      end.to change { recipient_balance.reload.available_millitokens }.by(20_000)
                                                                      .and change(BetterTogether::C3::Token, :count).by(1)

      expect(settlement.reload.status).to eq('completed')
      expect(settlement.c3_token).to be_present
      expect(settlement.completed_at).to be_present
    end

    it 'marks the BalanceLock as settled' do
      lock = BetterTogether::C3::BalanceLock.find_by(lock_ref: lock_ref)
      settlement.complete!(payer_balance: payer_balance.reload, recipient_balance: recipient_balance.reload)
      expect(lock.reload.status).to eq('settled')
    end

    it 'raises if settlement is not pending' do
      settlement.update_columns(status: 'completed')
      expect do
        settlement.complete!(payer_balance: payer_balance.reload, recipient_balance: recipient_balance.reload)
      end.to raise_error(ActiveRecord::RecordInvalid)
    end

    it 'delivers a c3_settled notification' do
      allow(BetterTogether::C3::SettlementNotifier).to receive(:with).and_call_original
      settlement.complete!(payer_balance: payer_balance.reload, recipient_balance: recipient_balance.reload)
      expect(BetterTogether::C3::SettlementNotifier).to have_received(:with)
        .with(settlement: settlement, event_type: :c3_settled)
    end
  end

  describe '#cancel!' do
    it 'returns locked C3 to payer' do
      available_before = payer_balance.reload.available_millitokens
      settlement.cancel!(payer_balance: payer_balance.reload)
      # locked amount returned to available
      expect(payer_balance.reload.available_millitokens).to eq(available_before + 20_000)
    end

    it 'marks the BalanceLock as released' do
      lock = BetterTogether::C3::BalanceLock.find_by(lock_ref: lock_ref)
      settlement.cancel!(payer_balance: payer_balance.reload)
      expect(lock.reload.status).to eq('released')
    end

    it 'raises if settlement is not pending' do
      settlement.update_columns(status: 'cancelled')
      expect do
        settlement.cancel!(payer_balance: payer_balance.reload)
      end.to raise_error(ActiveRecord::RecordInvalid)
    end

    it 'delivers a c3_lock_released notification' do
      allow(BetterTogether::C3::SettlementNotifier).to receive(:with).and_call_original
      settlement.cancel!(payer_balance: payer_balance.reload)
      expect(BetterTogether::C3::SettlementNotifier).to have_received(:with)
        .with(settlement: settlement, event_type: :c3_lock_released)
    end
  end

  describe '#to_s' do
    it 'includes the short id, status and c3 amount' do
      s = settlement.to_s
      expect(s).to include('pending')
      expect(s).to include('C3')
    end
  end
end

# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Billing::EventResult do
  it 'accepts the shared outcome vocabulary and a subject' do
    subject_record = Object.new
    result = described_class.new(status: :processed, outcome_kind: 'refund_issued', subject: subject_record)

    expect(result).to have_attributes(outcome_kind: :refund_issued, subject: subject_record)
  end

  it 'makes both optional' do
    expect(described_class.new(status: :ignored)).to have_attributes(outcome_kind: nil, subject: nil)
  end

  it 'refuses an outcome kind it does not know, so a vendor event name cannot leak in' do
    expect { described_class.new(status: :processed, outcome_kind: :stripe_invoice_paid) }
      .to raise_error(ArgumentError, /unknown outcome_kind/)
  end

  it 'covers what a processor reports and what core services report' do
    expect(described_class::OUTCOME_KINDS).to include(:payment_failed, :dispute_opened, :trial_ending, :payment_claimed,
                                                      :payment_confirmed, :refund_recorded)
  end
end

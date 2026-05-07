# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Billing::Event do
  subject(:event) { build('better_together/billing/event') }

  it 'is valid with the factory defaults' do
    expect(event).to be_valid
  end

  it 'tracks processed state' do
    expect(event.processed?).to be(false)

    event.processing_status = 'processed'

    expect(event.processed?).to be(true)
  end

  it 'requires a supported processing status' do
    event.processing_status = 'unknown'

    expect(event).not_to be_valid
    expect(event.errors[:processing_status]).to be_present
  end
end

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

  it 'exposes the beneficiary community for compatibility' do
    expect(event.community).to eq(event.beneficiary)
  end

  it 'detects when payloads are redacted' do
    expect(event.payload_redacted?).to be(false)

    event.payload_redacted_at = Time.current

    expect(event.payload_redacted?).to be(true)
  end

  it 'redacts retained payloads in place' do
    event = create(
      'better_together/billing/event',
      payload: {
        'id' => 'evt_redact_123',
        'type' => 'customer.subscription.updated',
        'data' => {
          'object' => {
            'object' => 'subscription',
            'id' => 'sub_redact_123',
            'metadata' => { 'bt_community_id' => 'community-123' },
            'customer_email' => 'sensitive@example.com'
          }
        }
      }
    )

    event.redact_payload!

    expect(event.reload.payload_redacted_at).to be_present
    expect(event.payload['bt_payload_redacted']).to be(true)
    expect(event.payload.dig('data', 'object', 'customer_email')).to be_nil
    expect(event.payload.dig('data', 'object', 'metadata')).to eq({ 'bt_community_id' => 'community-123' })
  end

  it 'summarizes repeated failures and unresolved problematic events for operators' do
    create(
      'better_together/billing/event',
      billable_owner: event.billable_owner,
      beneficiary: event.beneficiary,
      processing_status: 'failed',
      attempt_count: 3,
      last_attempted_at: 8.hours.ago
    )
    create(
      'better_together/billing/event',
      billable_owner: event.billable_owner,
      beneficiary: event.beneficiary,
      processing_status: 'ignored',
      attempt_count: 1,
      last_attempted_at: 7.hours.ago
    )

    summary = described_class.operator_alert_summary(described_class.all)

    expect(summary[:total_problematic_count]).to eq(2)
    expect(summary[:failed_count]).to eq(1)
    expect(summary[:ignored_count]).to eq(1)
    expect(summary[:dead_lettered_count]).to eq(0)
    expect(summary[:repeated_failure_count]).to eq(1)
    expect(summary[:unresolved_count]).to eq(2)
    expect(summary[:oldest_unresolved_at]).to be <= 7.hours.ago
  end

  it 'promotes stale problematic events into the dead-letter candidate scope' do
    stale_event = create(
      'better_together/billing/event',
      processing_status: 'ignored',
      attempt_count: 1,
      last_attempted_at: 8.hours.ago
    )

    expect(described_class.eligible_for_dead_lettering).to include(stale_event)
  end
end

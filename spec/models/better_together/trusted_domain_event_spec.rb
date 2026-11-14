# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::TrustedDomainEvent do
  let(:platform) { create(:better_together_platform) }

  def create_event(**attrs)
    described_class.create!(platform:, event_type: 'domain_added', domain: 'org.example', **attrs)
  end

  it 'validates the event type and channel', :aggregate_failures do
    expect(described_class.new(platform:, event_type: 'bogus', domain: 'a.test')).not_to be_valid
    expect(described_class.new(platform:, event_type: 'account_created', domain: 'a.test', via: 'bogus')).not_to be_valid
  end

  it 'is append-only', :aggregate_failures do
    event = create_event

    expect { event.update!(domain: 'x.test') }.to raise_error(ActiveRecord::ReadOnlyRecord)
    expect { event.destroy }.to raise_error(ActiveRecord::ReadOnlyRecord)
  end

  it 'survives removal of its trusted domain' do
    trusted = create(:platform_trusted_domain, platform:, domain: 'org.example')
    event = create_event(platform_trusted_domain: trusted)

    trusted.destroy!

    expect(event.reload.platform_trusted_domain_id).to be_nil
  end
end

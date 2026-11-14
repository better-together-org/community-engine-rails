# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::TrustedDomains::Grant, '.call limits and notifications' do
  include ActiveJob::TestHelper

  let!(:platform) { configure_host_platform }
  let(:trusted_domain) { create(:platform_trusted_domain, platform:, domain: 'trusted.example') }
  let!(:steward) do
    user = find_or_create_test_user('manager@example.test', 'SecureTest123!@#', :platform_manager)
    user.person
  end

  def grant(person = create(:better_together_person))
    described_class.call(trusted_domain:, person:, via: 'oauth')
  end

  it 'notifies platform stewards of a grant', :aggregate_failures do
    perform_enqueued_jobs { grant }

    notification = Noticed::Notification.where(recipient: steward).joins(:event)
                                        .find_by(noticed_events: { type: 'BetterTogether::TrustedDomainGrantNotifier' })
    expect(notification).to be_present
    expect(notification.event.title).to include('trusted.example')
  end

  it 'does not notify when nothing was granted' do
    person = create(:better_together_person)
    platform.community.person_community_memberships.create!(member: person, role: trusted_domain.role, status: 'active')

    expect { perform_enqueued_jobs { grant(person) } }
      .not_to(change { Noticed::Event.where(type: 'BetterTogether::TrustedDomainGrantNotifier').count })
  end

  describe 'hourly limit' do
    before { stub_const("#{described_class}::HOURLY_LIMIT", 2) }

    it 'holds grants past the limit, logs once and notifies once', :aggregate_failures do
      2.times { grant }
      held = create(:better_together_person)
      results = Array.new(2) { perform_enqueued_jobs { grant(held) } }

      expect(results.map(&:status)).to eq(%i[rate_limited rate_limited])
      expect(platform.community.person_community_memberships.where(member: held)).to be_empty
      expect(BetterTogether::TrustedDomainEvent.where(event_type: 'grant_rate_limited').count).to eq(1)
    end

    it 'counts the window per domain', :aggregate_failures do
      2.times { grant }
      other = create(:platform_trusted_domain, platform:, domain: 'other.example')

      result = described_class.call(trusted_domain: other, person: create(:better_together_person), via: 'oauth')

      expect(result).to be_granted
    end

    it 'resumes after the window passes' do
      2.times { grant }
      BetterTogether::TrustedDomainEvent.update_all(created_at: 2.hours.ago) # rubocop:disable Rails/SkipsModelValidations

      expect(grant).to be_granted
    end
  end
end

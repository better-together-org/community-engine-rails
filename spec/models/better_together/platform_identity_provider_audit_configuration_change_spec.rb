# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::PlatformIdentityProvider, '#audit_configuration_change' do
  let(:platform) { create(:better_together_platform) }
  let(:github) { create(:better_together_platform, identifier: 'github-audit', external: true) }

  it 'records created and updated events without secret values', :aggregate_failures do
    events = []
    sub = ActiveSupport::Notifications.subscribe(BetterTogether::TenancyAudit::EVENT) { |*, payload| events << payload }
    row = create(:better_together_platform_identity_provider, platform:, provider_platform: github,
                                                              client_secret: 'topsecretvalue')
    row.update!(client_secret: 'anothersecretvalue')
    ActiveSupport::Notifications.unsubscribe(sub)

    expect(events.pluck(:action)).to include('identity_provider.created', 'identity_provider.updated')
    expect(events.to_json).not_to match(/topsecretvalue|anothersecretvalue/)
  end
end

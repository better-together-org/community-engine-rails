# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::MembershipRequestNotificationService do
  it 'only names reviewer roles that the default role set seeds' do
    roles_file = BetterTogether::Engine.root.join('config/seeds/better_together/rbac/records/roles.yml')
    seeded = YAML.load_file(roles_file)['records'].map { |role| role['key'] }
    named = described_class::COMMUNITY_REVIEWER_ROLES + described_class::PLATFORM_REVIEWER_ROLES +
            BetterTogether::TrustedDomains::NotifyStewards::STEWARD_ROLES

    expect(named - seeded).to be_empty
  end
end

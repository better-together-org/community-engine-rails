# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::AccessControlBuilder do
  let(:platform) { BetterTogether::Platform.find_by(host: true) || create(:better_together_platform, :host) }

  before { configure_host_platform }

  describe '.seed_data' do
    it 'plants the default roles, permissions and assignments from the rbac packet' do
      described_class.seed_data(platform:)

      expect(BetterTogether::Role.find_by(identifier: 'community_organizer').name).to eq('Community Organizer')
      expect(BetterTogether::Role.find_by(identifier: 'platform_member')).to be_present
      expect(BetterTogether::ResourcePermission.find_by(identifier: 'manage_platform')).to be_present
    end

    it 'assigns permissions to roles' do
      described_class.seed_data(platform:)

      organizer = BetterTogether::Role.find_by!(identifier: 'community_organizer')
      expect(organizer.resource_permissions.pluck(:identifier)).to include('delete_community', 'manage_community_roles')
      expect(BetterTogether::Role.find_by!(identifier: 'community_member').resource_permissions.pluck(:identifier))
        .to contain_exactly('read_community', 'list_community')
    end

    it 'is idempotent' do
      described_class.seed_data(platform:)
      expect { described_class.seed_data(platform:) }
        .not_to(change { [BetterTogether::Role.count, BetterTogether::ResourcePermission.count, BetterTogether::RoleResourcePermission.count] })
    end
  end
end

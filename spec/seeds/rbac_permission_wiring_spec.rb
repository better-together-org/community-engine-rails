# frozen_string_literal: true

require 'rails_helper'
require 'yaml'

# Guards against permission drift: a seeded permission that no role holds, or that no code
# checks, silently does nothing. Every permission must be granted by the seed packet and
# checked in the code, or be listed below with the reason it is not.
# rubocop:disable-next RSpec/LeakyLocalVariable
RSpec.describe 'RBAC seed packet wiring' do # rubocop:disable RSpec/DescribeClass
  root = BetterTogether::Engine.root
  packet = root.join('config/seeds/better_together/rbac/records')

  permissions = YAML.safe_load_file(packet.join('resource_permissions.yml'))['records'].map { |r| r['key'] }
  granted = YAML.safe_load_file(packet.join('role_resource_permissions.yml'))['records']
                .to_set { |r| r['refs']['resource_permission'].split(':').last }

  # Seeded and checked in code, but held by no default role: grantable to a custom role only.
  reserved_ungranted = {
    'create_community' => 'Creation is gated by the community creation agreement and manager status, not a role.',
    'manage_platform_users' => 'Least privilege (f86f1722f): user accounts and emails are in no default platform ' \
                               'role; grant it to a custom role deliberately.',
    'create_person' => 'Opt-in profile administration; no default role holds it.',
    'read_person' => 'Opt-in read of private profiles; no default role holds it.',
    'update_person' => 'Opt-in profile administration; no default role holds it.',
    'delete_person' => 'Opt-in profile deletion; no default role holds it.',
    'list_person' => 'Opt-in full directory listing; no default role holds it.'
  }.freeze

  # Seeded and granted, but not literally checked: access is decided by privacy, membership or
  # platform-manager rules today. Kept as a stable vocabulary for roles, navigation and the API.
  reserved_unchecked = {
    'create_community' => 'Creation is decided in CommunityPolicy#create? by agreement and manager status.',
    'read_community' => 'Read access follows privacy and membership, not a permission check.',
    'list_community' => 'Listing follows privacy and membership, not a permission check.',
    'manage_community_notifications' => 'Reserved for community notification settings; no screen checks it yet.',
    'read_platform' => 'Platform visibility follows privacy; no check yet.',
    'update_platform' => 'Platform editing is gated by manage_platform and manage_platform_settings.',
    'delete_platform' => 'Platform deletion is gated by manage_platform.',
    'list_platform' => 'Platform listing follows privacy; no check yet.',
    'manage_platform_data_privacy' => 'Reserved for the data privacy screens; gated by manage_platform today.',
    'manage_platform_database' => 'Reserved for database tooling; gated by host platform manager today.',
    'manage_platform_deployment' => 'Reserved for deployment tooling; gated by host platform manager today.',
    'view_platform_logs' => 'Reserved for log screens; gated by host platform manager today.',
    'view_network' => 'Reserved for network views; connections use manage_network_connections.',
    'manage_federation_auth' => 'Reserved for federation auth screens; gated by manage_platform today.'
  }.freeze

  files = Dir[root.join('app/**/*.{rb,erb}'), root.join('lib/**/*.{rb,rake}'),
              root.join('config/seeds/better_together/navigation/records/*.yml')]
  checked_text = files.flat_map { |f| File.readlines(f, chomp: true) }
                      .map(&:strip).reject { |l| l.start_with?('#', '<%#') }.join("\n")
  checked = ->(identifier) { checked_text.match?(/['"]#{identifier}['"]|:#{identifier}\b/) }

  it 'finds the seeded permissions' do
    expect(permissions.size).to be > 40
  end

  permissions.each do |identifier|
    it "#{identifier} is granted to a role or listed as reserved ungranted" do
      expect(granted.include?(identifier) || reserved_ungranted.key?(identifier)).to be(true)
    end

    it "#{identifier} is checked in code or listed as reserved unchecked" do
      expect(checked.call(identifier) || reserved_unchecked.key?(identifier)).to be(true)
    end
  end

  it 'keeps the reserved lists honest' do
    stale_ungranted = reserved_ungranted.keys.select { |i| granted.include?(i) || permissions.exclude?(i) }
    stale_unchecked = reserved_unchecked.keys.select { |i| checked.call(i) || permissions.exclude?(i) }

    expect([stale_ungranted, stale_unchecked]).to eq([[], []])
  end
end

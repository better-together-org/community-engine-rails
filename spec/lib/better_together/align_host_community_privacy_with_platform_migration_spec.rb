# frozen_string_literal: true

require 'rails_helper'
require BetterTogether::Engine.root.join('db/migrate/20261009210000_align_host_community_privacy_with_platform')

RSpec.describe 'Align host community privacy with platform migration' do # rubocop:disable RSpec/DescribeClass
  subject(:migration) { AlignHostCommunityPrivacyWithPlatform.new }

  let(:host_platform) { BetterTogether::Platform.find_by(host: true) || create(:better_together_platform, :host, privacy: 'public') }

  # Migration.verbose is process-global; restore it so later specs asserting on migration output still see it.
  around do |example|
    previous = ActiveRecord::Migration.verbose
    migration.verbose = false
    example.run
  ensure
    ActiveRecord::Migration.verbose = previous
  end

  it 'aligns a drifted host community with its platform' do
    host_platform.community.update_columns(privacy: 'private')

    migration.up

    expect(host_platform.community.reload.privacy).to eq(host_platform.privacy)
  end

  it 'leaves other communities alone', :aggregate_failures do
    other = create(:better_together_community, privacy: 'private')
    host_platform.community.update_columns(privacy: 'private')

    migration.up

    expect(other.reload.privacy).to eq('private')
    expect(host_platform.community.reload.privacy).to eq(host_platform.privacy)
  end

  it 'is idempotent' do
    host_platform.community.update_columns(privacy: 'private')

    2.times { migration.up }

    expect(host_platform.community.reload.privacy).to eq(host_platform.privacy)
  end
end

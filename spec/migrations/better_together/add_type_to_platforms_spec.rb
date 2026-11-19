# frozen_string_literal: true

require 'rails_helper'
require BetterTogether::Engine.root.join('db/migrate/20261116200000_add_type_to_platforms')

RSpec.describe AddTypeToPlatforms, :no_auth do
  let!(:host_platform) { configure_host_platform }
  let(:oidc_identifier) { "oidc-#{SecureRandom.hex(8)}" }
  let!(:hosted) { untyped(create(:platform, locality: 'local')) }
  let!(:github) { untyped(create(:platform, :remote, identifier: 'github')) }
  let!(:oidc) { untyped(create(:platform, :remote, identifier: oidc_identifier)) }
  let!(:peer) { untyped(create(:platform, :remote, identifier: 'peer-communityengine')) }

  def migrate(direction)
    ActiveRecord::Migration.suppress_messages { described_class.new.public_send(direction) }
  end

  def untyped(platform)
    ActiveRecord::Base.connection.execute('SET CONSTRAINTS ALL IMMEDIATE') # flush deferred FK checks before DDL
    ActiveRecord::Base.connection.change_column_null(:better_together_platforms, :type, true)
    platform.update_columns(type: nil) # rubocop:disable Rails/SkipsModelValidations
    platform
  end

  def type_of(platform)
    BetterTogether::Platform.where(id: platform.id).pick(:type)
  end

  before do
    untyped(host_platform)
    migrate(:up)
  end

  it 'classifies every existing row', :aggregate_failures do
    expect(type_of(host_platform)).to eq('BetterTogether::OperatorPlatform')
    expect(type_of(hosted)).to eq('BetterTogether::HostedPlatform')
    expect(type_of(github)).to eq('BetterTogether::OauthPlatform')
    expect(type_of(oidc)).to eq('BetterTogether::OauthPlatform')
    expect(type_of(peer)).to eq('BetterTogether::FederatedPlatform')
  end

  it 'loads each row as its subclass', :aggregate_failures do
    expect(BetterTogether::Platform.find(hosted.id)).to be_a(BetterTogether::HostedPlatform)
    expect(BetterTogether::Platform.find(peer.id)).to be_a(BetterTogether::FederatedPlatform)
    expect(BetterTogether::Platform.find_by(host: true)).to be_a(BetterTogether::OperatorPlatform)
  end

  it 'does not retype rows that already have a type' do
    hosted.update_columns(type: 'BetterTogether::FederatedPlatform') # rubocop:disable Rails/SkipsModelValidations

    migrate(:up)

    expect(type_of(hosted)).to eq('BetterTogether::FederatedPlatform')
  end

  it 'removes the column on rollback' do
    migrate(:down)

    expect(ActiveRecord::Base.connection.column_exists?(:better_together_platforms, :type)).to be false
  end

  it 'knows every provider platform identifier the identity provider registry creates' do
    registry_identifiers = BetterTogether::IdentityProviders.each.map(&:platform_identifier).compact.map(&:to_s)

    expect(described_class::OAUTH_IDENTIFIERS).to include(*registry_identifiers)
  end

  it 'knows the identifiers the external platform builder creates' do
    expect(described_class::OAUTH_IDENTIFIERS).to include(*BetterTogether::ExternalPlatformBuilder::OAUTH_PROVIDERS.pluck(:identifier))
  end
end

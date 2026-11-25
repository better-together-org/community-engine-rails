# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Platform STI types' do # rubocop:disable RSpec/DescribeClass
  let!(:host_platform) { configure_host_platform }

  [BetterTogether::OperatorPlatform, BetterTogether::HostedPlatform,
   BetterTogether::OauthPlatform, BetterTogether::FederatedPlatform].each do |klass|
    describe klass do
      it 'stays a Platform to routes, policies and roles', :aggregate_failures do
        expect(klass.superclass).to eq(BetterTogether::Platform)
        expect(klass.base_class).to eq(BetterTogether::Platform)
        expect(klass.model_name).to eq(BetterTogether::Platform.model_name)
        expect(klass.policy_class).to eq(BetterTogether::PlatformPolicy)
      end
    end
  end

  describe 'host uniqueness' do
    it 'rejects a second host row of a different subtype' do
      other = build(:platform, host: true)
      other.type = 'BetterTogether::OperatorPlatform'
      other = BetterTogether::OperatorPlatform.new(other.attributes.except('id', 'type'))

      expect(other).not_to be_valid
      expect(other.errors[:host]).to include(I18n.t('errors.models.host_single'))
    end

    it 'does not offer set_as_host when a host of another subtype exists' do
      candidate = BetterTogether::HostedPlatform.new
      candidate.set_as_host

      expect(candidate.host).to be false
    end
  end

  describe 'member role resource type' do
    it 'uses the base class for a subtype', :aggregate_failures do
      hosted = create(:platform, type: 'BetterTogether::HostedPlatform', locality: 'local')

      expect(BetterTogether::Platform.find(hosted.id)).to be_a(BetterTogether::HostedPlatform)
      expect(hosted.default_member_role.resource_type).to eq('BetterTogether::Platform')
    end
  end

  describe 'type inference for plain Platform records' do
    it 'derives the type from the host and external flags', :aggregate_failures do
      expect(create(:platform, locality: 'local').type).to eq('BetterTogether::HostedPlatform')
      expect(create(:platform, :remote, identifier: 'peer-one').type).to eq('BetterTogether::FederatedPlatform')
      expect(create(:platform, :remote, identifier: 'github').type).to eq('BetterTogether::OauthPlatform')
      expect(host_platform.reload.type).to eq('BetterTogether::OperatorPlatform')
    end
  end

  describe 'locality consistency' do
    it 'rejects a federated platform that is local' do
      platform = build(:platform, locality: 'local').becomes(BetterTogether::FederatedPlatform)

      expect(platform).not_to be_valid
      expect(platform.errors[:locality]).to be_present
    end

    it 'rejects a remote host row' do
      platform = build(:platform, host: true, locality: 'remote').becomes(BetterTogether::OperatorPlatform)

      expect(platform).not_to be_valid
    end

    it 'allows a remote hosted platform' do
      platform = BetterTogether::HostedPlatform.new(locality: 'remote')
      platform.valid?

      expect(platform.errors[:locality]).to be_empty
    end
  end

  describe BetterTogether::OauthPlatform do
    it 'recognises provider identifiers and not peers', :aggregate_failures do
      expect(described_class.provider_identifier?('github')).to be true
      expect(described_class.provider_identifier?("oidc-#{'a' * 16}")).to be true
      expect(described_class.provider_identifier?('peer-communityengine')).to be false
    end

    it 'creates providers as OauthPlatform and finds existing ones of any type', :aggregate_failures do
      created = described_class.find_or_create_provider!('github') do |platform|
        platform.name = 'Github'
        platform.url = 'https://github.com'
        platform.time_zone = 'UTC'
        platform.privacy = :public
      end

      expect(created).to be_a(described_class)
      expect(described_class.find_or_create_provider!('github').id).to eq(created.id)
    end
  end

  describe 'oauth_providers scope' do
    it 'excludes federated peers', :aggregate_failures do
      provider = create(:platform, :remote, identifier: 'google')
      peer = create(:platform, :remote, identifier: 'peer-two')

      expect(BetterTogether::Platform.oauth_providers).to include(provider)
      expect(BetterTogether::Platform.oauth_providers).not_to include(peer)
    end
  end
end

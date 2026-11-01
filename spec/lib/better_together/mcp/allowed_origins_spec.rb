# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Mcp::AllowedOrigins do
  let(:memory_cache) { ActiveSupport::Cache::MemoryStore.new }
  let(:host_platform) { BetterTogether::Platform.find_by!(host: true) }

  before do
    configure_host_platform
    allow(Rails).to receive(:cache).and_return(memory_cache)
    described_class.reset_cache!
    BetterTogether::PlatformDomain.delete_all
  end

  def create_domain(hostname, **attrs)
    create(:better_together_platform_domain, platform: host_platform, hostname:, **attrs)
  end

  describe '.allowed?' do
    it 'allows the hostname of an active platform domain' do
      create_domain('app.example.test')

      expect(described_class.allowed?('app.example.test')).to be(true)
    end

    it 'ignores case and a trailing dot' do
      create_domain('app.example.test')

      expect(described_class.allowed?('APP.Example.Test.')).to be(true)
    end

    it 'refuses a hostname that is not a platform domain' do
      create_domain('app.example.test')

      expect(described_class.allowed?('evil.example')).to be(false)
    end

    it 'refuses a blank hostname' do
      expect(described_class.allowed?('')).to be(false)
      expect(described_class.allowed?(nil)).to be(false)
    end

    it 'does not allow an inactive platform domain' do
      create_domain('primary.example.test', primary_flag: true)
      create_domain('old.example.test', active: false)

      expect(described_class.allowed?('old.example.test')).to be(false)
    end

    it 'allows the host of an internal platform url' do
      host_platform.update_columns(url: 'https://platform-url.example.test')
      described_class.reset_cache!

      expect(described_class.allowed?('platform-url.example.test')).to be(true)
    end

    it 'does not allow the url of an external (federated) platform' do
      create(:better_together_platform, external: true, host: false, url: 'https://peer.example.test')
      described_class.reset_cache!

      expect(described_class.allowed?('peer.example.test')).to be(false)
    end
  end

  describe 'fail closed' do
    it 'allows nothing when no domain, url or extra hostname resolves' do
      # The url column is unique, so give each row its own unparseable value.
      BetterTogether::Platform.find_each.with_index do |platform, index|
        platform.update_column(:url, "not a url #{index}") # rubocop:disable Rails/SkipsModelValidations
      end
      described_class.reset_cache!

      expect(described_class.hostnames).to be_empty
      expect(described_class.allowed?('anything.example')).to be(false)
    end

    it 'allows nothing when the database lookup fails' do
      allow(BetterTogether::PlatformDomain).to receive(:active).and_raise(ActiveRecord::StatementInvalid, 'boom')

      expect(described_class.allowed?('app.example.test')).to be(false)
    end

    it 'does not cache a failed lookup' do
      allow(BetterTogether::PlatformDomain).to receive(:active).and_raise(ActiveRecord::StatementInvalid, 'boom')
      described_class.hostnames
      allow(BetterTogether::PlatformDomain).to receive(:active).and_call_original
      create_domain('app.example.test')

      expect(described_class.allowed?('app.example.test')).to be(true)
    end
  end

  describe 'MCP_ALLOWED_ORIGINS' do
    around do |example|
      original = ENV.fetch('MCP_ALLOWED_ORIGINS', nil)
      ENV['MCP_ALLOWED_ORIGINS'] = ' Extra.Example.Test , other.example.test ,'
      example.run
    ensure
      ENV['MCP_ALLOWED_ORIGINS'] = original
    end

    it 'adds the listed hostnames, normalised, alongside the platform domains' do
      create_domain('app.example.test')

      expect(described_class.hostnames).to include('extra.example.test', 'other.example.test', 'app.example.test')
    end
  end

  describe 'development defaults' do
    it 'allows the local hosts in development only' do
      allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('development'))

      expect(described_class.hostnames).to include('localhost', '127.0.0.1', '0.0.0.0')
    end

    it 'does not allow the local hosts outside development' do
      expect(described_class.hostnames).not_to include('localhost')
    end
  end

  describe 'following platform domain changes' do
    it 'allows a newly created domain on the next lookup' do
      expect(described_class.allowed?('new.example.test')).to be(false)

      create_domain('new.example.test')

      expect(described_class.allowed?('new.example.test')).to be(true)
    end

    it 'stops allowing a domain once it is deactivated' do
      create_domain('primary.example.test', primary_flag: true)
      other = create_domain('other.example.test')
      expect(described_class.allowed?('other.example.test')).to be(true)

      other.update!(active: false)

      expect(described_class.allowed?('other.example.test')).to be(false)
    end

    it 'stops allowing a domain once it is deleted' do
      domain = create_domain('gone.example.test')
      expect(described_class.allowed?('gone.example.test')).to be(true)

      domain.destroy

      expect(described_class.allowed?('gone.example.test')).to be(false)
    end

    it 'follows a hostname change' do
      domain = create_domain('before.example.test')
      expect(described_class.allowed?('before.example.test')).to be(true)

      domain.update!(hostname: 'after.example.test')

      expect(described_class.allowed?('before.example.test')).to be(false)
      expect(described_class.allowed?('after.example.test')).to be(true)
    end

    it 'follows a change to the platform url' do
      expect(described_class.allowed?('moved.example.test')).to be(false)

      host_platform.update!(url: 'https://moved.example.test')

      expect(described_class.allowed?('moved.example.test')).to be(true)
    end
  end
end

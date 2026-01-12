# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Platform do
  it 'has a valid factory' do
    platform = build(:better_together_platform)
    expect(platform).to be_valid
  end

  describe 'Factory traits' do
    describe ':host' do
      subject(:host_platform) { create(:better_together_platform, :host) }

      before do
        # Destroy any existing host platform for this test
        described_class.where(host: true).destroy_all
      end

      it 'creates a host platform' do
        expect(host_platform.host).to be true
        expect(host_platform.protected).to be true
      end
    end

    describe ':external' do
      subject(:external_platform) { create(:better_together_platform, :external) }

      it 'creates an external platform' do
        expect(external_platform.external).to be true
        expect(external_platform.host).to be false
      end
    end

    describe ':oauth_provider' do
      subject(:oauth_platform) { create(:better_together_platform, :oauth_provider) }

      it 'creates an OAuth provider platform' do
        expect(oauth_platform.external).to be true
        expect(oauth_platform.host).to be false
        expect(oauth_platform.name).to be_in(%w[GitHub Facebook Google Twitter])
        expect(oauth_platform.url).to be_present
      end
    end

    describe ':public' do
      subject(:public_platform) { create(:better_together_platform, :public) }

      it 'creates a public platform' do
        expect(public_platform.privacy).to eq('public')
      end
    end
  end

  describe 'validations' do
    subject(:platform) { build(:better_together_platform, host_url:) }

    context 'with valid http url' do
      let(:host_url) { 'http://example.org' }

      it { is_expected.to be_valid }
    end

    context 'with valid https url' do
      let(:host_url) { 'https://example.org' }

      it { is_expected.to be_valid }
    end

    context 'with invalid scheme' do
      let(:host_url) { 'javascript:alert(1)' }

      it 'is invalid' do
        expect(platform).not_to be_valid
        expect(platform.errors[:host_url]).to be_present
      end
    end
  end
end

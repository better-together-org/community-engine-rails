# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::OauthApplication do
  let(:platform) { configure_host_platform }

  before { platform }

  describe 'associations' do
    subject(:oauth_application) { build(:oauth_application) }

    it { is_expected.to belong_to(:owner).class_name('BetterTogether::Person').optional }

    it do
      expect(oauth_application).to have_many(:access_tokens)
        .class_name('BetterTogether::OauthAccessToken')
    end

    it do
      expect(oauth_application).to have_many(:access_grants)
        .class_name('BetterTogether::OauthAccessGrant')
    end
  end

  describe 'validations' do
    it 'validates presence of name' do
      app = build(:oauth_application, name: nil)
      expect(app).not_to be_valid
      expect(app.errors[:name]).to include("can't be blank")
    end

    it 'generates uid and secret automatically' do
      app = create(:oauth_application)
      expect(app.uid).to be_present
      expect(app.secret).to be_present
    end

    it 'generates unique uid values' do
      app1 = create(:oauth_application)
      app2 = create(:oauth_application)
      expect(app1.uid).not_to eq(app2.uid)
    end
  end

  describe '#trusted?' do
    it 'returns false for applications without an owner' do
      app = build(:oauth_application, owner: nil)
      expect(app.trusted?).to be false
    end

    it 'returns false for applications owned by regular users' do
      person = create(:person)
      app = build(:oauth_application, owner: person)
      # Regular person without manage_platform permission
      allow(person).to receive(:permitted_to?).with('manage_platform').and_return(false)
      expect(app.trusted?).to be false
    end

    it 'returns true for applications owned by platform managers' do
      person = create(:person)
      app = build(:oauth_application, owner: person)
      allow(person).to receive(:permitted_to?).with('manage_platform').and_return(true)
      expect(app.trusted?).to be true
    end
  end

  describe '.available_scopes' do
    it 'returns an array of available scopes' do
      scopes = described_class.available_scopes
      expect(scopes).to be_an(Array)
      expect(scopes).to include('read')
    end
  end

  describe '.permitted_attributes' do
    it 'returns the permitted attributes array' do
      attrs = described_class.permitted_attributes
      expect(attrs).to include(:name, :redirect_uri, :scopes, :confidential)
    end
  end

  describe 'scope management' do
    it 'allows applications with default scopes' do
      app = create(:oauth_application, scopes: 'read')
      expect(app).to be_valid
    end

    it 'allows applications with multiple scopes' do
      app = create(:oauth_application, scopes: 'read write read_communities')
      expect(app).to be_valid
      expect(app.scopes.to_a).to include('read', 'write', 'read_communities')
    end

    it 'rejects MCP-scoped applications for untrusted owners' do
      person = create(:person)
      allow(person).to receive(:permitted_to?).with('manage_platform').and_return(false)

      app = build(:oauth_application, owner: person, scopes: 'read mcp_access')

      expect(app).not_to be_valid
      expect(app.errors[:scopes].join).to include('mcp_access')
    end

    it 'allows MCP-scoped applications for trusted owners' do
      person = create(:person)
      allow(person).to receive(:permitted_to?).with('manage_platform').and_return(true)

      app = create(:oauth_application, owner: person, scopes: 'read mcp_access')

      expect(app.scopes.to_a).to include('mcp_access')
    end
  end

  describe 'owner association' do
    it 'can be created with an owner' do
      person = create(:person)
      app = create(:oauth_application, owner: person)
      expect(app.owner).to eq(person)
    end

    it 'can be created without an owner (system-level app)' do
      app = create(:oauth_application, owner: nil)
      expect(app.owner).to be_nil
      expect(app).to be_valid
    end
  end
end

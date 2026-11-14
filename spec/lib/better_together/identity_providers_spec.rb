# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::IdentityProviders do
  it 'ships github with its env vars and scope' do
    github = described_class.fetch(:github)

    expect([github.env_vars, github.scope]).to eq([%w[GITHUB_CLIENT_ID GITHUB_CLIENT_SECRET], 'user:email'])
  end

  it 'finds providers by string or symbol and returns nil when unknown' do
    expect([described_class.find('github')&.key, described_class.find(:nope)]).to eq([:github, nil])
  end

  it 'treats an email as unverified when the provider has no rule' do
    provider = described_class::Provider.new(key: :x)

    expect(provider.verified_email?(nil)).to be(false)
  end

  describe 'github verified-email rule' do
    let(:github) { described_class.fetch(:github) }

    let(:auth_for) do
      ->(emails) { OmniAuth::AuthHash.new(info: { email: 'a@example.test' }, extra: { all_emails: emails }) }
    end

    it 'accepts a verified matching entry' do
      expect(github.verified_email?(auth_for.call([{ 'email' => 'A@example.test', 'verified' => true }]))).to be(true)
    end

    it 'rejects an unverified entry' do
      expect(github.verified_email?(auth_for.call([{ 'email' => 'a@example.test', 'verified' => false }]))).to be(false)
    end

    it 'rejects a public profile email with no email list' do
      expect(github.verified_email?(auth_for.call([]))).to be(false)
    end
  end

  describe 'google verified-email rule' do
    let(:google) { described_class.fetch(:google_oauth2) }
    let(:auth_for) do
      ->(verified) { OmniAuth::AuthHash.new(info: { email: 'a@example.test', email_verified: verified }) }
    end

    it 'ships google with its env vars and scope' do
      expect([google.env_vars, google.scope]).to eq([%w[GOOGLE_CLIENT_ID GOOGLE_CLIENT_SECRET], 'email,profile'])
    end

    it 'accepts an asserted verified email' do
      expect(google.verified_email?(auth_for.call(true))).to be(true)
    end

    it 'rejects a false or missing assertion', :aggregate_failures do
      expect(google.verified_email?(auth_for.call(false))).to be(false)
      expect(google.verified_email?(auth_for.call(nil))).to be(false)
    end

    it 'rejects an assertion with no email' do
      auth = OmniAuth::AuthHash.new(info: { email_verified: true })

      expect(google.verified_email?(auth)).to be(false)
    end
  end
end

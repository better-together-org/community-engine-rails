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
end

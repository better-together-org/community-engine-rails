# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::FederationContentGrant do
  it 'has a valid factory' do
    expect(create(:better_together_federation_content_grant)).to be_valid
  end

  it 'defaults to allowed' do
    expect(create(:better_together_federation_content_grant).status).to eq('allowed')
  end

  it 'accepts the denied trait' do
    expect(create(:better_together_federation_content_grant, :denied)).to be_denied
  end

  it 'is unique per (federatable, platform_connection) pair' do
    post = create(:better_together_post)
    connection = create(:better_together_platform_connection)
    create(:better_together_federation_content_grant, federatable: post, platform_connection: connection)

    duplicate = build(:better_together_federation_content_grant, federatable: post, platform_connection: connection)

    expect(duplicate).not_to be_valid
  end

  it 'allows the same connection to be granted for a different federatable' do
    connection = create(:better_together_platform_connection)
    create(:better_together_federation_content_grant, platform_connection: connection)

    other_grant = build(:better_together_federation_content_grant, platform_connection: connection)

    expect(other_grant).to be_valid
  end
end

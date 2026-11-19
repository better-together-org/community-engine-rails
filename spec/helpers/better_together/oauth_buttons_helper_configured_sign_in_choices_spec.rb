# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::OauthButtonsHelper, '#configured_sign_in_choices' do
  let!(:platform) { configure_host_platform }
  let(:domain) { ensure_host_platform_domain(platform) }

  def oidc(issuer, **attrs)
    create(:better_together_platform_identity_provider, platform:, strategy: 'openid_connect',
                                                        provider_platform: nil, issuer:, **attrs)
      .tap { |row| row.update!(platform_domains: [domain]) }
  end

  before { allow(helper).to receive(:request).and_return(double(env: Rack::MockRequest.env_for("https://#{domain.hostname}/"))) }

  it 'offers one button per configured issuer, labelled by the organizer', :aggregate_failures do
    one = oidc('https://idp.one.example.org', label: 'Co-op login')
    two = oidc('https://idp.two.example.org')
    choices = helper.configured_sign_in_choices(BetterTogether::User).select { |c| c.key == :openid_connect }

    expect(choices.map(&:label)).to contain_exactly('Co-op login', 'idp.two.example.org')
    expect(choices.map(&:provider_id)).to contain_exactly(one.id, two.id)
  end

  it 'leaves out a disabled issuer' do
    oidc('https://idp.one.example.org', enabled: false)

    expect(helper.configured_sign_in_choices(BetterTogether::User).map(&:key)).not_to include(:openid_connect)
  end
end

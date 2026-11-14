# frozen_string_literal: true

require 'rails_helper'

# GHSA-m27g-v28p-f9fx: a forged Host / X-Forwarded-Host must never become the OAuth redirect_uri host.
RSpec.describe BetterTogether::OmniauthFullHost do
  let!(:host_platform) { configure_host_platform }
  let!(:domain) do
    create(:better_together_platform_domain, platform: host_platform, hostname: 'known.example.test', primary_flag: false)
  end

  def env_for(host, forwarded_host: nil)
    headers = { 'HTTP_HOST' => host }
    headers['HTTP_X_FORWARDED_HOST'] = forwarded_host if forwarded_host
    Rack::MockRequest.env_for("http://#{host}/users/auth/github", headers)
  end

  it 'uses the request host when it names an active platform domain' do
    expect(described_class.call(env_for('known.example.test'))).to eq(domain.url)
  end

  it 'ignores a forged Host header and falls back to the host platform URL' do
    result = described_class.call(env_for('evil.example.com'))

    expect(result).not_to include('evil.example.com')
    expect(result).to eq(host_platform.resolved_host_url)
  end

  it 'ignores a forged X-Forwarded-Host header' do
    result = described_class.call(env_for('localhost', forwarded_host: 'evil.example.com'))

    expect(result).not_to include('evil.example.com')
  end

  it 'ignores an inactive platform domain' do
    domain.update_columns(active: false, primary_flag: false) # rubocop:disable Rails/SkipsModelValidations
    Rails.cache.clear

    expect(described_class.call(env_for('known.example.test'))).not_to include('known.example.test')
  end
end

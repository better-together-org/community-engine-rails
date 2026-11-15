# frozen_string_literal: true

require 'rails_helper'

# P1-1: accounts belong to one platform; credentials and tokens work only there.
RSpec.describe 'Per platform accounts', :no_auth, :skip_host_setup do
  let(:password) { 'SecureTest123!@#' }
  let!(:host_platform) { configure_host_platform }
  let!(:host_domain) do
    BetterTogether::PlatformDomain.find_by(platform: host_platform, primary_flag: true) ||
      create(:better_together_platform_domain, :primary, platform: host_platform, hostname: 'host.example.test')
  end
  let(:tenant_platform) { create(:better_together_platform, :public) }
  let!(:tenant_domain) do
    domain = BetterTogether::PlatformDomain.find_by(platform: tenant_platform, primary_flag: true) ||
             create(:better_together_platform_domain, :primary, platform: tenant_platform)
    domain.update!(hostname: 'tenant.example.test')
    domain
  end

  def account_on(platform, email: 'same@example.test')
    create(:better_together_user, :confirmed, email:, password:, password_confirmation: password,
                                              platform:)
  end

  def sign_in_on(hostname, email)
    host! hostname
    post better_together.user_session_path(locale: I18n.default_locale),
         params: { user: { email:, password: } }
  end

  it 'allows the same email on two platforms' do
    account_on(host_platform)

    expect { account_on(tenant_platform) }.to change(BetterTogether::User, :count).by(1)
  end

  it 'refuses a duplicate email on the same platform' do
    account_on(host_platform)

    expect(build(:better_together_user, email: 'SAME@example.test', platform: host_platform)).not_to be_valid
  end

  it 'does not sign a host account in on the tenant domain', :aggregate_failures do
    account_on(host_platform)
    sign_in_on('tenant.example.test', 'same@example.test')

    expect(response).not_to redirect_to(%r{/en/?\z})
    get better_together.edit_user_registration_path(locale: I18n.default_locale)
    expect(response).not_to have_http_status(:ok)
  end

  it 'signs each platform account in only on its own domain', :aggregate_failures do
    account_on(host_platform)
    tenant_user = account_on(tenant_platform)
    sign_in_on('tenant.example.test', 'same@example.test')

    expect(controller_user_platform_id).to eq(tenant_user.platform_id)
  end

  it 'finds users by platform in the Devise funnel', :aggregate_failures do
    host_user = account_on(host_platform)
    tenant_user = account_on(tenant_platform)

    Current.set(platform: tenant_platform) do
      expect(BetterTogether::User.find_for_authentication(email: 'same@example.test')).to eq(tenant_user)
    end
    Current.set(platform: host_platform) do
      expect(BetterTogether::User.find_for_authentication(email: 'same@example.test')).to eq(host_user)
    end
  end

  it 'only honours a reset token on the issuing platform', :aggregate_failures do
    user = account_on(host_platform)
    raw = user.send_reset_password_instructions

    Current.set(platform: tenant_platform) do
      expect(BetterTogether::User.with_reset_password_token(raw)).to be_nil
    end
    Current.set(platform: host_platform) do
      expect(BetterTogether::User.with_reset_password_token(raw)).to eq(user)
    end
  end

  it 'logs out a session that crosses to another platform' do
    account_on(host_platform)
    sign_in_on('host.example.test', 'same@example.test')
    host! 'tenant.example.test'
    get better_together.edit_user_registration_path(locale: I18n.default_locale)

    expect(response).not_to have_http_status(:ok)
  end

  it 'does not configure a session cookie domain shared across hosts' do
    expect(Rails.application.config.session_options[:domain]).to be_nil
  end

  def controller_user_platform_id
    host! 'tenant.example.test'
    get better_together.edit_user_registration_path(locale: I18n.default_locale)
    return unless response.status == 200

    BetterTogether::User.find_by(email: 'same@example.test', platform: tenant_platform)&.platform_id
  end
end

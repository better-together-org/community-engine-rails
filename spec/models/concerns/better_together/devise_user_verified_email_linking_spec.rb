# frozen_string_literal: true

require 'rails_helper'

# Account-takeover coverage for OAuth sign-in: a provider identity may only attach to an existing account when the
# provider asserts the email is verified, and unverified signups go through Devise's normal confirmation email.
RSpec.describe BetterTogether::DeviseUser, '.from_omniauth verified-email linking' do # rubocop:disable RSpec/SpecFilePathFormat
  let(:user_class) { BetterTogether::User }
  let(:email) { 'victim@example.test' }
  let(:emails) { [] }

  let(:auth) do
    OmniAuth::AuthHash.new(
      provider: 'github', uid: '424242',
      info: { email:, name: 'Provider User', nickname: 'provideruser' },
      credentials: { token: 'tok' },
      extra: { all_emails: emails, raw_info: { login: 'provideruser', html_url: 'https://github.com/provideruser' } }
    )
  end

  def sign_in_with(auth_hash)
    user_class.from_omniauth(person_platform_integration: nil, auth: auth_hash, current_user: nil)
  end

  context 'when the provider verified the email' do
    let(:emails) { [{ 'email' => email, 'primary' => true, 'verified' => true }] }

    it 'links to an existing confirmed account' do
      existing = create(:user, email:)

      expect(sign_in_with(auth)).to eq(existing)
    end

    it 'confirms an existing unconfirmed account and rotates its password' do
      existing = create(:user, email:, password: 'AttackerChosen123!@#')
      existing.update_columns(confirmed_at: nil) # rubocop:disable Rails/SkipsModelValidations
      digest = existing.encrypted_password

      sign_in_with(auth)

      expect([existing.reload.confirmed?, existing.encrypted_password == digest]).to eq([true, false])
    end

    it 'creates a confirmed user and stores the integration for a new email' do
      result = sign_in_with(auth)

      expect([result.confirmed?, result.person_platform_integrations.count]).to eq([true, 1])
    end
  end

  context 'when the provider did not verify the email' do
    it 'refuses to link to an existing account' do
      create(:user, email:)

      expect { sign_in_with(auth) }.to raise_error(ArgumentError, /(has not verified|not verified)/)
    end

    it 'stores no integration on a refused collision' do
      create(:user, email:)

      expect do
        sign_in_with(auth)
      rescue ArgumentError
        nil
      end.not_to change(BetterTogether::PersonPlatformIntegration, :count)
    end

    it 'creates an unconfirmed user without an integration for a new email' do
      result = nil

      expect { result = sign_in_with(auth) }.not_to change(BetterTogether::PersonPlatformIntegration, :count)
      expect(result).to be_persisted.and have_attributes(confirmed?: false)
    end

    it 'issues a Devise confirmation token for a new email' do
      expect(sign_in_with(auth).confirmation_token).to be_present
    end
  end

  context 'when the provider is not in the catalog' do
    it 'treats the email as unverified' do
      create(:user, email:)
      unknown = OmniAuth::AuthHash.new(auth.to_h.merge('provider' => 'mystery'))

      expect { sign_in_with(unknown) }.to raise_error(ArgumentError)
    end
  end
end

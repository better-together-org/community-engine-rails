# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::DeviseUser do
  let(:user_class) { BetterTogether.user_class }
  let(:platform) { configure_host_platform }
  let(:community) { platform.community }

  before do
    platform # Ensure platform is created
  end

  def configure_host_platform
    host_platform = BetterTogether::Platform.find_by(host: true)
    if host_platform
      host_platform.update!(privacy: 'public')
    else
      host_platform = FactoryBot.create(:better_together_platform, :host, privacy: 'public')
    end

    wizard = BetterTogether::Wizard.find_or_create_by(identifier: 'host_setup')
    wizard.mark_completed

    host_platform
  end

  describe '.from_omniauth' do
    let(:github_auth_hash) do
      OmniAuth::AuthHash.new({
                               provider: 'github',
                               uid: '123456',
                               info: {
                                 email: 'test@example.com',
                                 name: 'Test User',
                                 nickname: 'testuser',
                                 image: 'https://avatars.githubusercontent.com/u/123456?v=4'
                               },
                               credentials: {
                                 token: 'github_access_token_123',
                                 secret: 'github_secret_456',
                                 expires_at: 1.hour.from_now.to_i
                               },
                               extra: {
                                 raw_info: {
                                   login: 'testuser',
                                   html_url: 'https://github.com/testuser'
                                 }
                               }
                             })
    end

    context 'when PersonPlatformIntegration is provided and has a user' do
      let!(:existing_integration) do
        create(:person_platform_integration,
               provider: 'github',
               uid: '123456',
               user: create(:user))
      end

      it 'updates the integration and returns existing user' do
        expect(BetterTogether::PersonPlatformIntegration).to receive(:update_or_initialize) # rubocop:todo RSpec/StubbedMock
          .with(existing_integration, github_auth_hash)
          .and_return(existing_integration)

        result = user_class.from_omniauth(
          person_platform_integration: existing_integration,
          auth: github_auth_hash,
          current_user: nil
        )

        expect(result).to eq(existing_integration.user)
      end
    end

    context 'when PersonPlatformIntegration exists but has no user' do
      let(:integration_without_user) do
        build(:person_platform_integration,
              provider: 'github',
              uid: '123456',
              user: nil)
      end

      context 'and current_user is present' do # rubocop:todo RSpec/NestedGroups
        let(:current_user) { create(:user, email: 'current@example.com') }

        it 'assigns integration to current user' do
          allow(BetterTogether::PersonPlatformIntegration).to receive(:update_or_initialize)
            .and_return(integration_without_user)

          result = user_class.from_omniauth(
            person_platform_integration: nil,
            auth: github_auth_hash,
            current_user: current_user
          )

          expect(result).to eq(current_user)
          expect(integration_without_user.user).to eq(current_user)
          expect(integration_without_user.person).to eq(current_user.person)
        end
      end

      context 'and user exists with same email' do # rubocop:todo RSpec/NestedGroups
        let!(:existing_user) { create(:user, email: 'test@example.com') }

        it 'assigns integration to existing user' do
          allow(BetterTogether::PersonPlatformIntegration).to receive(:update_or_initialize)
            .and_return(integration_without_user)

          result = user_class.from_omniauth(
            person_platform_integration: nil,
            auth: github_auth_hash,
            current_user: nil
          )

          expect(result).to eq(existing_user)
          expect(integration_without_user.user).to eq(existing_user)
          expect(integration_without_user.person).to eq(existing_user.person)
        end
      end

      context 'and no existing user is found' do # rubocop:todo RSpec/NestedGroups
        it 'creates new user with correct attributes' do
          allow(BetterTogether::PersonPlatformIntegration).to receive(:update_or_initialize)
            .and_return(integration_without_user)
          allow(integration_without_user).to receive_messages(name: 'Test User', handle: 'testuser')
          allow(integration_without_user).to receive(:user=)
          allow(integration_without_user).to receive(:person=)
          allow(integration_without_user).to receive(:save)

          expect do
            user_class.from_omniauth(
              person_platform_integration: nil,
              auth: github_auth_hash,
              current_user: nil
            )
          end.to change(user_class, :count).by(1)
                                           .and change(BetterTogether::Person, :count).by(1)

          new_user = user_class.last
          expect(new_user.email).to eq('test@example.com')
          expect(new_user.confirmed_at).to be_present # Should be confirmed
          expect(new_user.encrypted_password).to be_present # Password is hashed
          expect(new_user.person.name).to eq('Test User')
          expect(new_user.person.handle).to eq('testuser')
        end

        it 'extracts bio from GitHub OAuth data' do
          auth_with_bio = github_auth_hash.dup
          auth_with_bio.extra.raw_info[:bio] = 'Software developer from Canada'

          allow(BetterTogether::PersonPlatformIntegration).to receive(:update_or_initialize)
            .and_return(integration_without_user)
          allow(integration_without_user).to receive_messages(name: 'Test User', handle: 'testuser')
          allow(integration_without_user).to receive(:user=)
          allow(integration_without_user).to receive(:person=)
          allow(integration_without_user).to receive(:save)

          user_class.from_omniauth(
            person_platform_integration: nil,
            auth: auth_with_bio,
            current_user: nil
          )

          new_user = user_class.last
          expect(new_user.person.description).to eq('Software developer from Canada')
        end

        it 'uses existing person from platform invitation' do
          existing_person = create(:person, name: 'Invited Person', identifier: 'invited_person')
          platform_invitation = create(:platform_invitation, invitee: existing_person)

          allow(BetterTogether::PersonPlatformIntegration).to receive(:update_or_initialize)
            .and_return(integration_without_user)
          allow(integration_without_user).to receive_messages(name: 'OAuth Name', handle: 'oauthhandle')
          allow(integration_without_user).to receive(:user=)
          allow(integration_without_user).to receive(:person=)
          allow(integration_without_user).to receive(:save)

          expect do
            user_class.from_omniauth(
              person_platform_integration: nil,
              auth: github_auth_hash,
              current_user: nil,
              invitations: { platform: platform_invitation }
            )
          end.to change(user_class, :count).by(1)
                                           .and change(BetterTogether::Person, :count).by(0)

          new_user = user_class.last
          expect(new_user.person).to eq(existing_person)
        end

        it 'updates person from invitation with OAuth bio if missing' do
          existing_person = create(:person,
                                   name: 'Invited Person',
                                   identifier: 'invited_person',
                                   description: nil)
          platform_invitation = create(:platform_invitation, invitee: existing_person)

          auth_with_bio = github_auth_hash.dup
          auth_with_bio.extra.raw_info[:bio] = 'Developer bio from GitHub'

          allow(BetterTogether::PersonPlatformIntegration).to receive(:update_or_initialize)
            .and_return(integration_without_user)
          allow(integration_without_user).to receive_messages(name: 'OAuth Name', handle: 'oauthhandle')
          allow(integration_without_user).to receive(:user=)
          allow(integration_without_user).to receive(:person=)
          allow(integration_without_user).to receive(:save)

          user_class.from_omniauth(
            person_platform_integration: nil,
            auth: auth_with_bio,
            current_user: nil,
            invitations: { platform: platform_invitation }
          )

          existing_person.reload
          expect(existing_person.description).to eq('Developer bio from GitHub')
        end

        it 'does not override existing person description from invitation' do
          existing_person = create(:person,
                                   name: 'Invited Person',
                                   identifier: 'invited_person',
                                   description: 'Original bio from invitation')
          community_invitation = create(:community_invitation, invitee: existing_person)

          auth_with_bio = github_auth_hash.dup
          auth_with_bio.extra.raw_info[:bio] = 'Different bio from GitHub'

          allow(BetterTogether::PersonPlatformIntegration).to receive(:update_or_initialize)
            .and_return(integration_without_user)
          allow(integration_without_user).to receive_messages(name: 'OAuth Name', handle: 'oauthhandle')
          allow(integration_without_user).to receive(:user=)
          allow(integration_without_user).to receive(:person=)
          allow(integration_without_user).to receive(:save)

          user_class.from_omniauth(
            person_platform_integration: nil,
            auth: auth_with_bio,
            current_user: nil,
            invitations: { community: community_invitation }
          )

          existing_person.reload
          expect(existing_person.description).to eq('Original bio from invitation')
        end

        it 'handles missing name and handle gracefully' do
          allow(BetterTogether::PersonPlatformIntegration).to receive(:update_or_initialize)
            .and_return(integration_without_user)
          allow(integration_without_user).to receive_messages(name: nil, handle: nil)
          allow(integration_without_user).to receive(:user=)
          allow(integration_without_user).to receive(:person=)
          allow(integration_without_user).to receive(:save)

          user_class.from_omniauth(
            person_platform_integration: nil,
            auth: github_auth_hash,
            current_user: nil
          )

          new_user = user_class.last
          # When integration.name is nil, falls back to auth.info.name ('Test User')
          expect(new_user.person.name).to eq('Test User')
          # When integration.handle is nil, falls back to auth.info.nickname ('testuser')
          expect(new_user.person.handle).to eq('testuser')
        end

        it 'assigns integration to new user' do
          allow(BetterTogether::PersonPlatformIntegration).to receive(:update_or_initialize)
            .and_return(integration_without_user)
          allow(integration_without_user).to receive_messages(name: 'Test User', handle: 'testuser')

          expect(integration_without_user).to receive(:user=)
          expect(integration_without_user).to receive(:person=)
          expect(integration_without_user).to receive(:save)

          user_class.from_omniauth(
            person_platform_integration: nil,
            auth: github_auth_hash,
            current_user: nil
          )
        end
      end
    end

    context 'when PersonPlatformIntegration is nil' do
      it 'calls update_or_initialize with nil and auth' do
        expect(BetterTogether::PersonPlatformIntegration).to receive(:update_or_initialize) # rubocop:todo RSpec/StubbedMock
          .with(nil, github_auth_hash)
          .and_return(build(:person_platform_integration))

        user_class.from_omniauth(
          person_platform_integration: nil,
          auth: github_auth_hash,
          current_user: nil
        )
      end
    end

    context 'error handling' do
      let(:integration_without_user) do
        build(:person_platform_integration,
              provider: 'github',
              uid: '123456',
              user: nil)
      end

      it 'handles user creation failures gracefully' do
        allow(BetterTogether::PersonPlatformIntegration).to receive(:update_or_initialize)
          .and_return(integration_without_user)
        allow(integration_without_user).to receive_messages(name: 'Test User', handle: 'testuser')

        # Mock user creation to fail
        invalid_user = user_class.new(email: 'test@example.com')
        invalid_user.errors.add(:email, 'is invalid')

        allow(user_class).to receive(:new).and_return(invalid_user)
        allow(invalid_user).to receive(:save).and_return(false)

        result = user_class.from_omniauth(
          person_platform_integration: nil,
          auth: github_auth_hash,
          current_user: nil
        )

        expect(result).to be_nil
      end

      it 'handles missing email in auth hash' do
        auth_without_email = github_auth_hash.dup
        auth_without_email.info.delete(:email)

        expect do
          user_class.from_omniauth(
            person_platform_integration: nil,
            auth: auth_without_email,
            current_user: nil
          )
        end.not_to raise_error
      end
    end
  end

  describe '#set_attributes_from_auth' do
    let(:user) { build(:user) }
    let(:auth_hash) do
      OmniAuth::AuthHash.new({
                               info: {
                                 email: 'oauth@example.com',
                                 name: 'OAuth User'
                               }
                             })
    end

    it 'sets email from auth hash' do
      user.attributes_from_auth(auth_hash)
      expect(user.email).to eq('oauth@example.com')
    end

    it 'handles missing email gracefully' do
      auth_without_email = auth_hash.dup
      auth_without_email.info.delete(:email)

      expect do
        user.attributes_from_auth(auth_without_email)
      end.not_to raise_error

      expect(user.email).to be_nil
    end
  end
end

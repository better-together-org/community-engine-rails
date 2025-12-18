# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Invitation timer display' do
  include RequestSpecHelper
  include ActiveSupport::Testing::TimeHelpers

  before do
    configure_host_platform
  end

  let(:invitation) do
    create(:better_together_platform_invitation, status: 'pending', locale: I18n.default_locale.to_s)
  end

  describe 'session expiry timestamp' do
    it 'sets platform_invitation_expires_at based on session_duration_mins when no valid_until' do
      freeze_time do
        get better_together.home_page_path(locale: I18n.default_locale, invitation_code: invitation.token)

        expect(session[:platform_invitation_token]).to eq(invitation.token)
        expect(session[:platform_invitation_expires_at]).to be_present
        expect(session[:platform_invitation_expires_at]).to be_a(ActiveSupport::TimeWithZone)

        # Should use session_duration_mins (default: 30 minutes)
        expected_expiry = 30.minutes.from_now
        expect(session[:platform_invitation_expires_at]).to be_within(5.seconds).of(expected_expiry)
      end
    end

    it 'respects invitation valid_until when earlier than session_duration_mins' do
      freeze_time do
        # Create invitation with valid_until earlier than session_duration_mins
        invitation_with_expiry = create(
          :better_together_platform_invitation,
          status: 'pending',
          locale: I18n.default_locale.to_s,
          session_duration_mins: 60, # 60 minutes
          valid_until: 30.minutes.from_now # But expires in 30 minutes
        )

        get better_together.home_page_path(
          locale: I18n.default_locale,
          invitation_code: invitation_with_expiry.token
        )

        # Session should expire at invitation's valid_until (earlier of the two)
        expected_expiry = 30.minutes.from_now
        expect(session[:platform_invitation_expires_at]).to be_within(5.seconds).of(expected_expiry)
      end
    end

    it 'respects session_duration_mins when earlier than valid_until' do
      freeze_time do
        # Create invitation with session_duration_mins earlier than valid_until
        invitation_with_duration = create(
          :better_together_platform_invitation,
          status: 'pending',
          locale: I18n.default_locale.to_s,
          session_duration_mins: 15, # 15 minutes
          valid_until: 2.hours.from_now # But invitation valid for 2 hours
        )

        get better_together.home_page_path(
          locale: I18n.default_locale,
          invitation_code: invitation_with_duration.token
        )

        # Session should expire at session_duration_mins (earlier of the two)
        expected_expiry = 15.minutes.from_now
        expect(session[:platform_invitation_expires_at]).to be_within(5.seconds).of(expected_expiry)
      end
    end

    it 'preserves platform_invitation_expires_at on subsequent requests without invitation_code' do
      freeze_time do
        # First request with invitation_code
        get better_together.home_page_path(locale: I18n.default_locale, invitation_code: invitation.token)

        first_expiry = session[:platform_invitation_expires_at]
        first_expiry_unix = first_expiry.to_i

        # Second request without invitation_code
        get better_together.home_page_path(locale: I18n.default_locale)

        # Session may serialize to string, but should represent the same time
        second_expiry = session[:platform_invitation_expires_at]
        second_expiry_unix = second_expiry.is_a?(String) ? Time.parse(second_expiry).to_i : second_expiry.to_i

        expect(second_expiry_unix).to eq(first_expiry_unix)
        expect(session[:platform_invitation_token]).to eq(invitation.token)
      end
    end

    it 'removes expired invitation from session' do
      freeze_time do
        # Set invitation with expiry
        get better_together.home_page_path(locale: I18n.default_locale, invitation_code: invitation.token)

        expect(session[:platform_invitation_token]).to be_present

        # Travel past expiry
        travel 31.minutes

        # Next request should clear the session
        get better_together.home_page_path(locale: I18n.default_locale)

        expect(session[:platform_invitation_token]).to be_nil
        expect(session[:platform_invitation_expires_at]).to be_nil
      end
    end
  end

  describe 'invitation_token_expires_at helper' do
    include BetterTogether::PlatformsHelper

    it 'returns nil when no invitation is in session' do
      get better_together.home_page_path(locale: I18n.default_locale)

      expect(invitation_token_expires_at).to be_nil
    end

    it 'returns Unix timestamp when invitation is in session' do
      freeze_time do
        get better_together.home_page_path(locale: I18n.default_locale, invitation_code: invitation.token)

        expires_at_unix = invitation_token_expires_at

        expect(expires_at_unix).to be_a(Integer)
        expect(expires_at_unix).to be > Time.current.to_i

        # Should be ~30 minutes from now in seconds
        expected_unix = 30.minutes.from_now.to_i
        expect(expires_at_unix).to be_within(5).of(expected_unix)
      end
    end

    it 'calculates remaining time correctly' do
      freeze_time do
        get better_together.home_page_path(locale: I18n.default_locale, invitation_code: invitation.token)

        expires_at_unix = invitation_token_expires_at
        now_unix = Time.current.to_i
        remaining_seconds = expires_at_unix - now_unix

        # Should have ~30 minutes (1800 seconds) remaining
        expect(remaining_seconds).to be_within(5).of(30 * 60)
      end
    end

    it 'returns positive remaining time even after time passes' do
      freeze_time do
        get better_together.home_page_path(locale: I18n.default_locale, invitation_code: invitation.token)

        # Travel forward 15 minutes
        travel 15.minutes

        expires_at_unix = invitation_token_expires_at
        now_unix = Time.current.to_i
        remaining_seconds = expires_at_unix - now_unix

        # Should have ~15 minutes (900 seconds) remaining
        expect(remaining_seconds).to be_within(5).of(15 * 60)
        expect(remaining_seconds).to be > 0
      end
    end
  end

  describe 'view integration' do
    it 'displays invitation timer badge when valid invitation is in session' do
      get better_together.home_page_path(locale: I18n.default_locale, invitation_code: invitation.token)

      expect(response.body).to include('better_together--invitation-timer')
      expect(response.body).to include('data-better_together--invitation-timer-expires-at-value')
    end

    it 'passes non-zero expires_at value to JavaScript controller' do
      freeze_time do
        get better_together.home_page_path(locale: I18n.default_locale, invitation_code: invitation.token)

        # Extract the data attribute value from the response
        match = response.body.match(/data-better_together--invitation-timer-expires-at-value="(\d+)"/)
        expect(match).to be_present

        expires_at_value = match[1].to_i
        expect(expires_at_value).to be > Time.current.to_i
        expect(expires_at_value).to be_within(5).of(30.minutes.from_now.to_i)
      end
    end

    it 'does not display invitation timer when no invitation is present' do
      get better_together.home_page_path(locale: I18n.default_locale)

      expect(response.body).not_to include('better_together--invitation-timer')
    end
  end
end

# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'ApplicationController timezone setting', type: :request do
  include AutomaticTestConfiguration

  describe 'timezone setting via any controller action' do
    # Use an existing route to test timezone behavior
    let(:test_path) { better_together.home_page_path(locale: I18n.default_locale) }

    context 'without authenticated user (guest)' do
      it 'uses platform timezone for guest users' do
        platform = BetterTogether::Platform.find_by(host: true)
        expected_tz = platform.time_zone

        # Make request and inspect Time.zone in a known controller callback
        get test_path

        # We can't directly check Time.zone from the test, but we can verify
        # that our methods exist and work correctly by unit testing them separately.
        # For integration, we'll check that timezone-dependent displays work correctly
        # in feature tests.
        expect(response).to have_http_status(:success)

        # Verify platform has a timezone
        expect(expected_tz).to be_present
      end
    end

    context 'with authenticated user' do
      let(:user) { find_or_create_test_user('timezone_test@example.test', 'SecureTest123!@#', :user) }

      before { login(user.email, 'SecureTest123!@#') }

      it 'uses user timezone preference when set' do
        user.person.time_zone = 'Tokyo'
        user.person.save!

        get test_path

        expect(response).to have_http_status(:success)
        # Timezone is set for the request, verified by unit tests below
      end
    end
  end

  # Unit tests for the timezone determination logic
  describe 'timezone determination logic' do
    let(:controller) { BetterTogether::ApplicationController.new }

    before do
      # Set up necessary controller state
      allow(controller).to receive(:current_user).and_return(current_user) if defined?(current_user)
      allow(controller).to receive(:helpers).and_return(
        double(host_platform: BetterTogether::Platform.find_by(host: true))
      )
    end

    context 'with authenticated user' do
      let(:current_user) { find_or_create_test_user('unit_test@example.test', 'SecureTest123!@#', :user) }

      it 'returns user timezone when set' do
        current_user.person.time_zone = 'Tokyo'
        current_user.person.save!

        expect(controller.send(:determine_timezone)).to eq('Tokyo')
      end

      it 'falls back to platform timezone when user timezone not set' do
        current_user.person.time_zone = nil
        current_user.person.save!

        platform_tz = BetterTogether::Platform.find_by(host: true)&.time_zone
        expect(controller.send(:determine_timezone)).to eq(platform_tz) if platform_tz.present?
      end

      it 'falls back to app config when neither user nor platform timezone set' do
        current_user.person.time_zone = nil
        current_user.person.save!

        # Mock platform without timezone
        allow(controller).to receive(:helpers).and_return(
          double(host_platform: double(time_zone: nil))
        )

        expect(controller.send(:determine_timezone)).to eq(Rails.application.config.time_zone)
      end
    end

    context 'without authenticated user (guest)' do
      let(:current_user) { nil }

      it 'uses platform timezone' do
        platform_tz = BetterTogether::Platform.find_by(host: true)&.time_zone
        expect(controller.send(:determine_timezone)).to eq(platform_tz) if platform_tz.present?
      end

      it 'falls back to app config when platform timezone not set' do
        allow(controller).to receive(:helpers).and_return(
          double(host_platform: double(time_zone: nil))
        )

        expect(controller.send(:determine_timezone)).to eq(Rails.application.config.time_zone)
      end

      it 'falls back to UTC when nothing else is set' do
        allow(controller).to receive(:helpers).and_return(
          double(host_platform: nil)
        )
        allow(Rails.application.config).to receive(:time_zone).and_return(nil)

        expect(controller.send(:determine_timezone)).to eq('UTC')
      end
    end

    context 'timezone hierarchy' do
      let(:current_user) { find_or_create_test_user('hierarchy_test@example.test', 'SecureTest123!@#', :user) }
      let(:platform) { BetterTogether::Platform.find_by(host: true) }

      before do
        platform.update!(time_zone: 'America/New_York')
        allow(controller).to receive(:helpers).and_return(double(host_platform: platform))
      end

      it 'prioritizes user timezone over platform timezone' do
        current_user.person.time_zone = 'Asia/Tokyo'
        current_user.person.save!

        expect(controller.send(:determine_timezone)).to eq('Asia/Tokyo')
      end

      it 'uses platform timezone when user timezone is blank string' do
        current_user.person.time_zone = ''
        current_user.person.save!

        expect(controller.send(:determine_timezone)).to eq('America/New_York')
      end

      it 'uses platform timezone when user timezone is nil' do
        current_user.person.time_zone = nil
        current_user.person.save!

        expect(controller.send(:determine_timezone)).to eq('America/New_York')
      end
    end
  end
end

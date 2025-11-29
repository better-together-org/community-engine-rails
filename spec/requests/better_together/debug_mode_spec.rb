# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Debug Mode Functionality' do
  include ActiveSupport::Testing::TimeHelpers

  let(:locale) { I18n.default_locale }
  let(:test_path) { better_together.home_page_path(locale:) }

  describe 'Debug mode activation via parameter' do
    it 'enables debug mode when ?debug=true is passed' do
      get test_path, params: { debug: 'true' }

      expect(session[:stimulus_debug]).to be true
      expect(session[:stimulus_debug_expires_at]).to be_present
      expect(session[:stimulus_debug_expires_at]).to be > Time.current
    end

    it 'sets expiration to 30 minutes from now' do
      travel_to Time.current do
        get test_path, params: { debug: 'true' }

        expect(session[:stimulus_debug_expires_at]).to be_within(1.second).of(30.minutes.from_now)
      end
    end

    it 'clears debug mode when ?debug=false is passed' do
      # First enable debug mode
      get test_path, params: { debug: 'true' }
      expect(session[:stimulus_debug]).to be true

      # Then disable it
      get test_path, params: { debug: 'false' }
      expect(session[:stimulus_debug]).to be_nil
      expect(session[:stimulus_debug_expires_at]).to be_nil
    end

    it 'clears debug mode when ?debug=anything is passed' do
      # First enable debug mode
      get test_path, params: { debug: 'true' }
      expect(session[:stimulus_debug]).to be true

      # Then disable with any other value
      get test_path, params: { debug: 'off' }
      expect(session[:stimulus_debug]).to be_nil
    end
  end

  describe 'Debug mode persistence across requests' do
    it 'persists debug mode across subsequent requests' do
      # Enable debug mode
      get test_path, params: { debug: 'true' }
      expect(session[:stimulus_debug]).to be true

      # Make another request without debug param
      get test_path
      expect(session[:stimulus_debug]).to be true
    end

    it 'maintains debug mode for multiple page visits' do
      get test_path, params: { debug: 'true' }

      5.times do
        get test_path
        expect(session[:stimulus_debug]).to be true
      end
    end
  end

  describe 'Debug mode expiration' do
    it 'expires debug mode after 30 minutes' do
      travel_to Time.current do
        get test_path, params: { debug: 'true' }
        expect(session[:stimulus_debug]).to be true

        # Travel 31 minutes into the future
        travel 31.minutes

        # Next request should clear expired session
        get test_path
        expect(session[:stimulus_debug]).to be_nil
        expect(session[:stimulus_debug_expires_at]).to be_nil
      end
    end

    it 'does not expire before 30 minutes' do
      travel_to Time.current do
        get test_path, params: { debug: 'true' }

        # Travel 29 minutes (still within expiration window)
        travel 29.minutes

        get test_path
        expect(session[:stimulus_debug]).to be true
      end
    end
  end

  describe 'Debug mode meta tags and headers' do
    context 'when debug mode is enabled' do
      before do
        get test_path, params: { debug: 'true' }
      end

      it 'includes stimulus-debug meta tag set to true' do
        get test_path
        expect(response.body).to include('<meta name="stimulus-debug" content="true"')
      end

      it 'includes cache-control meta tags' do
        get test_path
        expect(response.body).to include('http-equiv="Cache-Control" content="no-cache, no-store, must-revalidate"')
        expect(response.body).to include('http-equiv="Pragma" content="no-cache"')
        expect(response.body).to include('http-equiv="Expires" content="0"')
      end

      it 'sets no-cache HTTP headers' do
        get test_path
        # Rails may override the header format, so check it contains the no-store directive
        expect(response.headers['Cache-Control']).to include('no-store')
        expect(response.headers['Pragma']).to eq('no-cache')
        expect(response.headers['Expires']).to eq('0')
      end

      it 'sets noindex,nofollow robots meta tag' do
        get test_path
        expect(response.body).to include('<meta name="robots" content="noindex,nofollow"')
      end
    end

    context 'when debug mode is disabled' do
      it 'includes stimulus-debug meta tag set to false' do
        get test_path
        expect(response.body).to include('<meta name="stimulus-debug" content="false"')
      end

      it 'does not include cache-control meta tags' do
        get test_path
        expect(response.body).not_to include('http-equiv="Cache-Control"')
        expect(response.body).not_to include('http-equiv="Pragma"')
        expect(response.body).not_to include('http-equiv="Expires"')
      end

      it 'does not set no-cache HTTP headers' do
        get test_path
        expect(response.headers['Cache-Control']).not_to eq('no-cache, no-store, must-revalidate')
      end

      it 'sets default robots meta tag' do
        get test_path
        expect(response.body).to include('<meta name="robots" content="index,follow"')
      end
    end
  end

  describe 'Debug mode with immediate parameter override' do
    it 'enables debug mode immediately with parameter even without session' do
      get test_path, params: { debug: 'true' }

      # Check that meta tag shows true immediately
      expect(response.body).to include('<meta name="stimulus-debug" content="true"')
    end

    it 'disables debug mode immediately with parameter even with active session' do
      # Enable debug mode via session
      get test_path, params: { debug: 'true' }
      expect(session[:stimulus_debug]).to be true

      # Disable via parameter
      get test_path, params: { debug: 'false' }

      # Meta tag should show false immediately
      expect(response.body).to include('<meta name="stimulus-debug" content="false"')
    end
  end

  describe 'Helper method stimulus_debug_enabled?' do
    it 'returns true when debug parameter is present' do
      get test_path, params: { debug: 'true' }
      expect(controller.helpers.stimulus_debug_enabled?).to be true
    end

    it 'returns true when session is active and not expired' do
      travel_to Time.current do
        get test_path, params: { debug: 'true' }

        # Make another request without parameter
        get test_path
        expect(controller.helpers.stimulus_debug_enabled?).to be true
      end
    end

    it 'returns false when session has expired' do
      travel_to Time.current do
        get test_path, params: { debug: 'true' }

        travel 31.minutes
        get test_path

        expect(controller.helpers.stimulus_debug_enabled?).to be false
      end
    end

    it 'returns false when no debug mode is active' do
      get test_path
      expect(controller.helpers.stimulus_debug_enabled?).to be false
    end
  end

  describe 'Security: preventing cache and indexing' do
    it 'prevents page caching when debug is enabled' do
      get test_path, params: { debug: 'true' }

      # Verify cache prevention directive is set
      expect(response.headers['Cache-Control']).to include('no-store')
    end

    it 'prevents search engine indexing when debug is enabled' do
      get test_path, params: { debug: 'true' }

      # Verify robots meta tag prevents indexing
      expect(response.body).to match(/<meta name="robots" content="noindex,nofollow"/)
    end

    it 'allows normal caching when debug is disabled' do
      get test_path

      # Should not have the strict no-cache headers
      expect(response.headers['Cache-Control']).not_to eq('no-cache, no-store, must-revalidate')
    end

    it 'allows search engine indexing when debug is disabled' do
      get test_path

      # Should have normal indexing permission
      expect(response.body).to match(/<meta name="robots" content="index,follow"/)
    end
  end
end

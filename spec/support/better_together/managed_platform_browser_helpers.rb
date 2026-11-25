# frozen_string_literal: true

module BetterTogether
  # Browser-spec scaffolding for working on a managed platform's own domain, as its steward would.
  # One app server on one port serves every hostname (Chrome maps *.test to it, see spec/support/capybara.rb),
  # so run browser specs that use this on a single worker (WORKERS=1).
  #
  #   let(:setup) { managed_platform_setup(managed_attributes: { host_url: managed_host_url }) }
  #   before { use_managed_origin(setup) }
  #   after  { reset_managed_origin }
  #   sign_in_on_managed_platform(setup.managed_steward)
  module ManagedPlatformBrowserHelpers
    MANAGED_SERVER_PORT = 43_999

    def managed_host
      @managed_host ||= "club-#{SecureRandom.hex(3)}.managed.test"
    end

    # The platform's own URL carries no port: domain resolution goes by hostname.
    def managed_host_url
      "http://#{managed_host}"
    end

    def managed_origin
      "#{managed_host_url}:#{MANAGED_SERVER_PORT}"
    end

    def managed_url(path)
      "#{managed_origin}#{path}"
    end

    # Relative visits (the sign-in helper) must reach the managed hostname, not Capybara's own 127.0.0.1.
    def use_managed_origin(setup)
      Capybara.server_port = MANAGED_SERVER_PORT
      Capybara.app_host = managed_origin
      Capybara.asset_host = managed_origin
      Current.platform = setup.operator_platform
      setup.operator_platform.update!(privacy: 'public', requires_invitation: false)
    end

    def reset_managed_origin
      Capybara.app_host = nil
      Capybara.asset_host = nil
      Current.platform = nil
    end

    def sign_in_on_managed_platform(steward)
      visit managed_url(better_together.new_user_session_path(locale: I18n.default_locale))
      capybara_sign_in_user(steward.email, 'SecureTest123!@#')
    end
  end
end

RSpec.configure { |config| config.include BetterTogether::ManagedPlatformBrowserHelpers, :docs_screenshot }

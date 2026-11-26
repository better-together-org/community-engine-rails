# frozen_string_literal: true

# Multi-hostname test support (stack MDS).
#
# One app instance and one port serve every hostname, as in production. Request specs choose the
# hostname with `host!`, mailer and job specs choose the platform with `Current.platform`, and
# browser specs reach extra hostnames under *.localhost on the one Capybara server.
module MultiHostnameHelpers
  # Chrome resolves every *.localhost name to the loopback address, so these hostnames reach the one
  # Capybara server with no resolver rule and no driver option.
  HOSTNAME_SUFFIX = 'mds.localhost'

  # A platform with a primary domain for the hostname (https, no port), ready to be served.
  def create_platform_on_hostname(hostname, **attributes)
    existing = BetterTogether::Platform.find_by(host_url: "http://#{hostname}")
    return heal_platform_domain(existing) if existing

    create(:better_together_platform, host: false, privacy: 'public', requires_invitation: false,
                                      host_url: "http://#{hostname}", **attributes).tap do |platform|
      BetterTogether::PlatformDomain.clear_resolution_cache! if BetterTogether::PlatformDomain.respond_to?(:clear_resolution_cache!)
      Rails.cache.clear
      platform.reload
    end
  end

  # Platforms outlive the :deletion cleanup but their domain rows do not, so put the domain back.
  def heal_platform_domain(platform)
    platform.sync_primary_platform_domain! unless platform.platform_domains.active.exists?
    Rails.cache.clear
    platform.reload
  end

  # Runs the block as the platform that owns the hostname: requests use that Host, and code that
  # reads Current.platform (jobs, mailers, URL helpers) sees it.
  def on_hostname(hostname)
    domain = BetterTogether::PlatformDomain.resolve(hostname)
    raise ArgumentError, "no active platform domain for #{hostname}" unless domain

    previous_host = respond_to?(:host!) ? integration_session.host : nil
    host!(hostname) if respond_to?(:host!)
    ::Current.set(platform: domain.platform, platform_domain: domain) { yield domain.platform }
  ensure
    host!(previous_host) if previous_host
  end

  # The URL a browser spec visits for a hostname served by the one Capybara server.
  def multi_host_url(hostname, path = '/')
    "http://#{hostname}:#{Capybara.current_session.server.port}#{path}"
  end
end

# The host platform's domain rows live in a table the :deletion cleanup of JS/feature/system examples
# empties, so later examples would meet a host with no domain. Put back what was there.
module HostDomainHealing
  def self.snapshot
    host = BetterTogether::Platform.find_by(host: true)
    return [] unless host

    host.platform_domains.map { |domain| domain.attributes.except('created_at', 'updated_at') }
  end

  def self.restore(rows)
    rows.each do |attributes|
      next if BetterTogether::PlatformDomain.exists?(hostname: attributes['hostname'])

      BetterTogether::PlatformDomain.new(attributes).save!(validate: false)
    end
    Rails.cache.clear
  end
end

RSpec.configure do |config|
  config.include MultiHostnameHelpers

  config.after(:each, :multi_host) do
    # Platforms are never cleaned by the :deletion strategy, so remove the ones this example made.
    BetterTogether::Platform.where(host: false).find_each do |platform|
      platform.destroy if platform.host_url.to_s.end_with?(".#{MultiHostnameHelpers::HOSTNAME_SUFFIX}")
    end
  end

  config.around do |example|
    if example.metadata[:js] || example.metadata[:feature] || example.metadata[:system]
      rows = HostDomainHealing.snapshot
      example.run
      HostDomainHealing.restore(rows)
    else
      example.run
    end
  end
end

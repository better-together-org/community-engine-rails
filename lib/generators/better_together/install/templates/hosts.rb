# frozen_string_literal: true

# Allowed hosts for production. Set APP_HOSTS to a comma separated list (ALLOWED_HOSTS is read as an alias).
# Hostnames of active platform domains are allowed as well, without listing them here, once this list is
# not empty. To turn that off: BetterTogether.authorize_hosts_from_domains = false
# The engine already applies its Content Security Policy to host apps; extend it with
# BetterTogether.register_content_security_policy_sources(:img_src, 'https://cdn.example.org').
Rails.application.config.hosts.concat(BetterTogether::HostAuthorization.env_hosts)

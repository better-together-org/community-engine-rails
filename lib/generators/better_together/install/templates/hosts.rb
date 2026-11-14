# frozen_string_literal: true

# Allowed hosts for production. Set APP_HOSTS to a comma separated list.
# The engine already applies its Content Security Policy to host apps; extend it with
# BetterTogether.register_content_security_policy_sources(:img_src, 'https://cdn.example.org').
Rails.application.config.hosts.concat(ENV.fetch('APP_HOSTS', '').split(',').map(&:strip).compact_blank)

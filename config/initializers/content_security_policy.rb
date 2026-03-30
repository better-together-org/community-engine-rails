# frozen_string_literal: true

# See: https://guides.rubyonrails.org/security.html#content-security-policy
require_relative '../../lib/better_together/content_security_policy_sources'

Rails.application.configure do
  config.content_security_policy do |p|
    # Base policy
    p.default_src :self
    p.base_uri    :self

    # Allow JS from self (importmap), blob for ES module shims, CDN sources used by importmap pins,
    # and the configured asset host when host apps serve digested assets from a separate CDN domain.
    p.script_src(*BetterTogether::ContentSecurityPolicySources.script_sources)
    p.style_src(*BetterTogether::ContentSecurityPolicySources.style_sources)
    # These helpers keep the strict baseline while allowing trusted origins from
    # env defaults and optional per-platform settings.
    p.img_src(*BetterTogether::ContentSecurityPolicySources.img_sources)
    p.font_src(*BetterTogether::ContentSecurityPolicySources.font_sources)
    p.frame_src(*BetterTogether::ContentSecurityPolicySources.frame_sources)
    p.connect_src :self,
                  :wss # ActionCable WebSocket connections
    p.form_action :self
    p.frame_ancestors(*BetterTogether::ContentSecurityPolicySources.frame_ancestor_sources)
    p.object_src :none
  end

  # Generate nonce for inline scripts and apply to Turbo/UJS
  # Use cryptographically random nonce per request — never derive from session ID
  config.content_security_policy_nonce_generator = ->(_request) { SecureRandom.base64(16) }
  config.content_security_policy_nonce_directives = %w[script-src]

  # Enforcing mode — blocks policy violations (required for V7 XSS defence).
  # Previously report-only; switched to enforcing before staging merge.
  config.content_security_policy_report_only = false
end

# frozen_string_literal: true

# See: https://guides.rubyonrails.org/security.html#content-security-policy
Rails.application.configure do
  config.content_security_policy do |p|
    # Base policy
    p.default_src :self
    p.base_uri    :self

    # Allow JS from self (importmap), blob for ES module shims, and CDN sources used by importmap pins
    p.script_src  :self, :blob,
                  'https://cdn.jsdelivr.net',
                  'https://cdnjs.cloudflare.com',
                  'https://unpkg.com',
                  'https://ga.jspm.io'
    p.style_src   :self, :unsafe_inline, # allow inline styles for ActionText/Trix
                  'https://cdn.jsdelivr.net',
                  'https://cdnjs.cloudflare.com',
                  'https://unpkg.com'
    p.img_src     :self, :data, :blob,
                  'https://*.tile.openstreetmap.org' # Leaflet map tiles
    p.font_src    :self, :data
    p.connect_src :self,
                  :wss # ActionCable WebSocket connections
    p.form_action :self
    p.frame_ancestors :none
    p.object_src :none
  end

  # Generate nonce for inline scripts and apply to Turbo/UJS
  config.content_security_policy_nonce_generator = ->(request) { request.session.id.to_s }
  config.content_security_policy_nonce_directives = %w[script-src]

  # Report-Only mode initially — switch to enforcing once validated in staging
  config.content_security_policy_report_only = true
end

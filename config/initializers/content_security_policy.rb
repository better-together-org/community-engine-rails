# frozen_string_literal: true

# See: https://guides.rubyonrails.org/security.html#content-security-policy
# Rails.application.configure do
#   config.content_security_policy do |p|
#     # Base policy
#     p.default_src :self
#     p.base_uri    :self

#     # Allow JS from self (importmap) and blob for ES module shims; prefer nonce for inline
#     p.script_src  :self, :blob, :https
#     p.style_src   :self, :https, :unsafe_inline # allow inline styles for ActionText; tighten if possible
#     p.img_src     :self, :data, :blob
#     p.font_src    :self, :https, :data
#     p.connect_src :self
#     p.form_action :self
#     p.frame_ancestors :none
#     p.object_src :none

#     # Upgrade insecure requests in supported browsers
#     p.upgrade_insecure_requests true

#     # Include nonce for UJS/Turbo inline scripts
#     p.script_src_attr :none
#     p.script_src_elem :self, :blob, :https
#   end

#   # Set additional secure headers
#   config.action_dispatch.default_headers.merge!(
#     {
#       'Referrer-Policy' => 'strict-origin-when-cross-origin',
#       'X-Content-Type-Options' => 'nosniff',
#       'X-Frame-Options' => 'DENY',
#       'Permissions-Policy' => 'geolocation=(), microphone=(), camera=(), accelerometer=(), payment=()'
#     }
#   )
# end

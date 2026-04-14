# frozen_string_literal: true

# config/importmap.rb

# Pin everything under app/javascript as a fallback
pin_all_from File.expand_path('../app/javascript/better_together', __dir__),
             under: 'better_together'
pin_all_from File.expand_path('../app/javascript/better_together/trix_extensions', __dir__),
             under: 'better_together/trix-extensions'
pin_all_from File.expand_path('../app/javascript/channels/better_together', __dir__),
             under: 'channels/better_together'

pin_all_from File.expand_path('../app/javascript/channels', __dir__),
             under: 'channels'

# Pin the specific controllers namespace properly
pin_all_from File.expand_path('../app/javascript/controllers/better_together', __dir__),
             under: 'controllers/better_together'

# Core dependencies
pin '@hotwired/turbo-rails', to: 'turbo.js', preload: true
pin '@hotwired/stimulus', to: 'stimulus.js', preload: true
pin '@popperjs/core', to: 'popper.js', preload: true
pin 'stimulus-loading', to: 'stimulus-loading.js', preload: true

# Rails and other dependencies
pin '@rails/actioncable', to: 'actioncable.esm.js', preload: true
pin '@rails/activestorage', to: 'activestorage.js', preload: true
pin '@rails/actiontext', to: 'actiontext.js', preload: true

# Frontend libraries
pin 'bootstrap', to: 'bootstrap.min.js', preload: true
pin 'chart.js', to: 'chart.js', preload: true # @4.5.1
pin 'slim-select', to: 'slim-select.js', preload: true # @2.13.1
pin 'trix', to: 'trix.js', preload: true # @2.1.18
pin 'mermaid_umd', to: 'mermaid/mermaid.min.js', preload: true # @11.14.0
pin 'mermaid', to: 'mermaid_shim.js', preload: true

pin 'masonry', to: 'masonry.min.js' # @4.2.2
pin 'imagesloaded', to: 'imagesloaded.min.js' # @5.0.0

pin 'leaflet', preload: true # @1.9.4
pin 'leaflet-gesture-handling', to: 'leaflet-gesture-handling.js', preload: true # Ensure it is preloaded # @1.2.2
pin 'leaflet-providers', preload: true # @2.0.0

# Optional: Module shims
pin 'es-module-shims', to: 'es-module-shims.js', preload: true # @2.8.0

# Application entry point
pin 'application', preload: true

# The UMD bundle populates globalThis.CommunityEngine when loaded.
# It must be pinned under a distinct name so it loads and runs before the shim.
pin 'community_engine_js_umd', to: 'community-engine.umd.js',
                               integrity: 'sha384-nBGUV8c8f2uCS8r5d2F/RyIN//oOr/E7f6hcZ3JpaHUCti6zhdNZagRbyZgv7duj'
# The shim re-exports named symbols from the UMD global as ESM named exports.
pin 'community_engine_js', to: 'community_engine_js_shim.js'

# frozen_string_literal: true

# config/importmap.rb

# Pin everything under app/javascript as a fallback
pin_all_from File.expand_path('../app/javascript/better_together', __dir__), under: 'better_together'
pin_all_from File.expand_path('../app/javascript/better_together/trix_extensions', __dir__),
             under: 'better_together/trix-extensions'
pin_all_from File.expand_path('../app/javascript/better_together/channels', __dir__), under: 'better_together/channels'

# Pin the specific controllers namespace properly
pin_all_from File.expand_path('../app/javascript/controllers/better_together', __dir__),
             under: 'controllers/better_together'

# Core dependencies
pin '@hotwired/turbo-rails', to: 'turbo.js', preload: true
pin '@hotwired/stimulus', to: 'stimulus.js', preload: true
pin '@popperjs/core', to: 'popper.js', preload: true
pin 'stimulus-loading', to: 'stimulus-loading.js', preload: true

# Rails and other dependencies
pin '@rails/actioncable', to: 'actioncable.js', preload: true
pin '@rails/activestorage', to: 'activestorage.js', preload: true
pin '@rails/actiontext', to: 'actiontext.js', preload: true

# Frontend libraries
pin 'bootstrap', to: 'bootstrap.min.js', preload: true
pin 'chart.js', to: 'https://cdn.jsdelivr.net/npm/chart.js', preload: true
pin 'slim-select', to: 'https://cdnjs.cloudflare.com/ajax/libs/slim-select/2.9.2/slimselect.umd.min.js', preload: true
pin 'trix', to: 'https://unpkg.com/trix@2.0.8/dist/trix.umd.min.js', preload: true

pin 'masonry', to: 'masonry.min.js' # @4.2.2
pin 'imagesloaded', to: 'imagesloaded.min.js' # @5.0.0

pin 'leaflet' # @1.9.4
pin 'leaflet-providers' # @2.0.0
# pin "trix" # @2.1.13

# Optional: Module shims
pin 'es-module-shims', to: 'https://ga.jspm.io/npm:es-module-shims@1.8.2/dist/es-module-shims.js', preload: true

# Application entry point
pin 'application', preload: true

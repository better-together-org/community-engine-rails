# frozen_string_literal: true

# config/importmap.rb

pin '@hotwired/turbo-rails', to: 'turbo.js', preload: true
pin '@hotwired/stimulus', to: 'stimulus.js', preload: true
pin '@popperjs/core', to: 'popper.js', preload: true
pin '@rails/actioncable', to: 'actioncable.js', preload: true
pin '@rails/activestorage', to: 'activestorage.js', preload: true
pin '@rails/actiontext', to: 'actiontext.js', preload: true

pin 'application', preload: true
pin 'bootstrap', to: 'bootstrap.min.js', preload: true
pin 'es-module-shims', to: 'https://ga.jspm.io/npm:es-module-shims@1.8.2/dist/es-module-shims.js', preload: true
pin 'stimulus-loading', to: 'stimulus-loading.js', preload: true
pin 'trix', to: 'https://unpkg.com/trix@2.0.8/dist/trix.umd.min.js', preload: true

pin_all_from 'app/javascript/better_together/controllers', under: 'better_together/controllers'
pin_all_from 'app/javascript/better_together/trix-extensions', under: 'better_together/trix-extensions'

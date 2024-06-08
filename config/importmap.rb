# frozen_string_literal: true

# config/importmap.rb

pin_all_from File.expand_path('../app/javascript/better_together', __dir__)
pin_all_from 'app/javascript/better_together/controllers', under: 'better_together/controllers', to: 'controllers'
# pin_all_from 'app/javascript/better_together/trix-extensions', under: 'trix-extensions', to: 'trix-extensions'

pin '@hotwired/turbo-rails', to: 'turbo.min.js'
pin '@hotwired/stimulus', to: 'stimulus.min.js'
pin 'stimulus-loading', to: 'stimulus-loading.js', preload: true # Ensure correct path and file extension

pin 'bootstrap', to: 'bootstrap.min.js', preload: true
pin '@popperjs/core', to: 'popper.js', preload: true
pin 'trix'
pin '@rails/actiontext', to: 'actiontext.js'

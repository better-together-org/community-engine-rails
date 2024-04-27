# config/importmap.rb
# pin_all_from File.expand_path("../app/assets/javascript", __dir__)
pin_all_from File.expand_path('../app/javascript', __dir__)
pin_all_from 'app/javascript/controllers', under: 'controllers', to: 'controllers'
pin_all_from 'app/javascript/trix-extensions', under: 'trix-extensions', to: 'trix-extensions'
pin '@hotwired/turbo-rails', to: 'turbo.min.js'
pin '@hotwired/stimulus', to: 'stimulus.min.js'
pin '@hotwired/stimulus-loading', to: 'stimulus-loading'
# TODO: Check if this is compiled for prod: https://github.com/hotwired/stimulus-rails/issues/108

pin 'bootstrap', to: 'bootstrap.min.js', preload: true
pin '@popperjs/core', to: 'popper.js', preload: true
pin 'trix'
pin '@rails/actiontext', to: 'actiontext.js'

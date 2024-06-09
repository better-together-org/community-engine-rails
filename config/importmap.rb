# frozen_string_literal: true

# config/importmap.rb

pin "application", preload: true
pin 'bootstrap', to: 'bootstrap.min.js', preload: true
pin 'stimulus-loading', to: 'stimulus-loading.js', preload: true
pin 'trix', preload: true
pin "@hotwired/turbo-rails", to: "turbo.min.js", preload: true
pin "@hotwired/stimulus", to: "stimulus.min.js", preload: true
pin '@popperjs/core', to: 'popper.js', preload: true
pin '@rails/actiontext', to: 'actiontext.js', preload: true
pin_all_from "app/javascript/controllers", under: "controllers"

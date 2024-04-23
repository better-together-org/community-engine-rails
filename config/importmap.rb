# config/importmap.rb
# pin_all_from File.expand_path("../app/assets/javascript", __dir__)
pin_all_from File.expand_path("../app/javascript", __dir__)
pin_all_from "app/javascript/controllers", under: "controllers", to: 'controllers'
pin "@hotwired/turbo-rails", to: "turbo.min.js"
pin "@hotwired/stimulus", to: "stimulus.min.js"
pin "@hotwired/stimulus-loading", to: "stimulus-loading"
# TODO: Check if this is compiled for prod: https://github.com/hotwired/stimulus-rails/issues/108

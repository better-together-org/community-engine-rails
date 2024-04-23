# config/importmap.rb
# pin_all_from File.expand_path("../app/assets/javascript", __dir__)
pin_all_from File.expand_path("../app/javascript", __dir__)
pin_all_from "app/javascript/controllers", under: "controllers"
pin "@hotwired/turbo-rails", to: "turbo.min.js"
pin "@hotwired/stimulus", to: "stimulus.min.js"
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"

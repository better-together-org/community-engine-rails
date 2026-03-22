# frozen_string_literal: true

# Pin npm packages by running ./bin/importmap

# Pin all controllers from the host's app/javascript/controllers directory
pin_all_from File.expand_path('../app/javascript/controllers', __dir__), under: 'controllers'

pin 'application'

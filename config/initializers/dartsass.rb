# frozen_string_literal: true

# Configure Dart Sass to silence Bootstrap deprecation warnings
# These warnings are from Bootstrap's internal implementation and will be
# fixed when Bootstrap releases a Dart Sass 3.0 compatible version.
#
# Warnings silenced:
# - import: Bootstrap still uses @import (will be removed in Bootstrap 6)
# - global-builtin: Bootstrap uses global functions (type-of, unit, map-has-key)
# - color-functions: Bootstrap uses deprecated color functions (red, green, blue)

Rails.application.config.sass.quiet_deps = true
Rails.application.config.sass.silence_deprecations = %w[
  import
  global-builtin
  color-functions
]

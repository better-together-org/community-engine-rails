# frozen_string_literal: true

module BetterTogether
  # Shared capture wrapper for the docs screenshot specs: both devices, the same metadata shape and the
  # spec file as `source_spec`, so the screenshot sidecars and the coverage manifest can trace an image
  # back to the spec that produced it.
  module DocsScreenshotHelpers
    def docs_screenshot(name, role:, feature_set:, flow: nil, callouts: [], narrative: nil, &) # rubocop:disable Metrics/ParameterLists
      BetterTogether::CapybaraScreenshotEngine.capture(
        name,
        device: :both,
        metadata: {
          locale: I18n.default_locale, role:, feature_set:, flow:, source_spec: self.class.metadata[:file_path]
        }.compact,
        callouts:,
        narrative:,
        &
      )
    end
  end
end

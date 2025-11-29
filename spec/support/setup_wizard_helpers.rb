# frozen_string_literal: true

# Helpers for setup wizard specs to opt-out of the automatic host platform setup
# provided by AutomaticTestConfiguration.
#
# Usage:
# - include_context 'skip_host_setup'    # sets metadata to skip host setup for the example group
# - call skip_host_setup! inside an example/before block to mark the current example
# - any spec file under spec/features/setup_wizard will have the metadata applied automatically

RSpec.shared_context 'skip_host_setup', :skip_host_setup do
  # metadata-only context; AutomaticTestConfiguration will check for :skip_host_setup
end

module SetupWizardSpecHelpers
  # Mark the current example to skip host platform setup.
  # Useful in examples that need to simulate a fresh install / wizard flow.
  def skip_host_setup!
    if defined?(RSpec) && RSpec.respond_to?(:current_example) && RSpec.current_example
      RSpec.current_example.metadata[:skip_host_setup] = true
    elsif defined?(example) && example.respond_to?(:metadata)
      example.metadata[:skip_host_setup] = true
    end
  end
end

RSpec.configure do |config|
  config.include SetupWizardSpecHelpers

  # If a spec file is under spec/features/setup_wizard, ensure the example metadata
  # is marked early and any host records are neutralized. We run this with prepend: true
  # so it executes before AutomaticTestConfiguration's hooks.
  config.before(:each, :prepend, type: :feature) do |example|
    if example.file_path =~ %r{spec/features/setup_wizard}
      example.metadata[:skip_host_setup] = true

      BetterTogether::Platform.where(host: true).update_all(host: false) if defined?(BetterTogether::Platform)

      BetterTogether::Community.where(host: true).update_all(host: false) if defined?(BetterTogether::Community)

      BetterTogether::Wizard.where(identifier: 'host_setup').destroy_all if defined?(BetterTogether::Wizard)
      byebug # rubocop:todo Lint/Debugger
    end
  end

  # Ensure any previously-created host platform/community/wizard are neutralized
  # for examples that need a fresh wizard flow. Run this early so AutomaticTestConfiguration
  # won't detect a host from earlier tests.
  config.before(:each, :prepend, :skip_host_setup) do
    BetterTogether::Platform.where(host: true).update_all(host: false) if defined?(BetterTogether::Platform)

    BetterTogether::Community.where(host: true).update_all(host: false) if defined?(BetterTogether::Community)

    BetterTogether::Wizard.where(identifier: 'host_setup').destroy_all if defined?(BetterTogether::Wizard)
  end

  # Auto-apply the :skip_host_setup metadata for files under spec/features/setup_wizard
  config.define_derived_metadata(file_path: %r{spec/features/setup_wizard}) do |metadata|
    metadata[:skip_host_setup] = true
  end
end

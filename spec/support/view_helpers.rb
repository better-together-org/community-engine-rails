# frozen_string_literal: true

# Provide a minimal `current_person` helper for view specs so they can be
# stubbed with `allow(view).to receive(:current_person).and_return(person)`.
module ViewSpecHelpers
  def current_person
    nil
  end
end

RSpec.configure do |config|
  config.include ViewSpecHelpers, type: :view

  # Ensure the `view` object responds to `current_person` so tests can safely
  # stub it with `allow(view).to receive(:current_person).and_return(person)`
  config.before(type: :view) do
    view.define_singleton_method(:current_person) { nil } unless view.respond_to?(:current_person)
    # Provide a no-op `policy` method so tests can stub `view.policy(...)` safely.
    view.define_singleton_method(:policy) { |*| nil } unless view.respond_to?(:policy)
    # Make form helper methods available on the view (e.g., `required_label`)
    if defined?(BetterTogether::FormHelper)
      view.extend(BetterTogether::FormHelper)
    end

    # Make application-level helpers available on the view (e.g., `iana_time_zone_select`)
    if defined?(BetterTogether::ApplicationHelper)
      view.extend(BetterTogether::ApplicationHelper)
    end

    # Allow tests to call `platform.update!(time_zone: nil)` in view specs
    # Update the in-memory attribute without persisting to avoid DB NOT NULL
    # violations while letting the view reflect the change.
    # rubocop:disable RSpec/AnyInstance
    allow_any_instance_of(BetterTogether::Platform).to receive(:update!) do |instance, attrs = {}|
      attrs ||= {}
      instance.time_zone = attrs[:time_zone] if attrs.key?(:time_zone)
      true
    end
    # rubocop:enable RSpec/AnyInstance
  end
end

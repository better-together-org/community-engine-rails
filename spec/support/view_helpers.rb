# frozen_string_literal: true

# Provide a minimal `current_person` helper for view specs so they can be
# stubbed with `allow(view).to receive(:current_person).and_return(person)`.
module ViewSpecHelpers # :nodoc:
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

    # Make person-related helpers available on the view (e.g., `mention_profile_path`),
    # needed by shared partials like _governed_authors that render person mentions
    # outside a people/ controller context.
    if defined?(BetterTogether::PeopleHelper)
      view.extend(BetterTogether::PeopleHelper)
    end
  end
end

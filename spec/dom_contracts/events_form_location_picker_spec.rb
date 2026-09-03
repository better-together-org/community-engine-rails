# frozen_string_literal: true

require 'rails_helper'

# DOM contract for the event form's location picker: asserts the stable
# identifiers that the feature spec (spec/features/events/location_selector_spec.rb),
# the accessibility spec, the docs screenshots
# (spec/docs_screenshots/better_together/event_location_picker_spec.rb), and the
# Stimulus controllers target. Runs in normal CI (no RUN_DOCS_SCREENSHOTS gate).
RSpec.describe 'Event form location picker DOM contract', :as_platform_manager, type: :request do # rubocop:disable RSpec/DescribeClass
  # Attribute values are HTML-escaped in the response body (`->` becomes `-&gt;`),
  # so compare against the decoded document.
  def decoded_body
    CGI.unescapeHTML(response.body)
  end

  it 'exposes the picker, hidden fields, hint, and inline address fieldset' do # rubocop:disable RSpec/MultipleExpectations, RSpec/ExampleLength
    get "/#{I18n.default_locale}/events/new"

    expect(response).to have_http_status(:ok)
    body = decoded_body

    # Picker combobox + its wiring
    expect(body).to include('id="event_location_picker"')
    expect(body).to include('data-controller="better_together--slim-select"')
    expect(body).to include('data-better_together--location-selector-target="locationSelect"')
    expect(body).to match(/aria-describedby="[^"]*event_location_picker_hint[^"]*"/)
    expect(body).to include('better_together--slim-select:create->better_together--location-selector#revealNewRecord')

    # Hidden assignment fields
    expect(body).to include('data-better_together--location-selector-target="locationIdField"')
    expect(body).to include('data-better_together--location-selector-target="locationTypeField"')
    expect(body).to include('data-better_together--location-selector-target="simpleNameField"')
    expect(body).to include('name="event[location_attributes][location_id]"')
    expect(body).to include('name="event[location_attributes][location_type]"')
    expect(body).to include('name="event[location_attributes][name]"')

    # Single hint + live region
    expect(body).to include('id="event_location_picker_hint"')
    expect(body).to include('data-better_together--location-selector-target="announcement"')

    # Inline address fieldset (platform manager can create Address)
    expect(body).to include('id="event_location_new_address"')
    expect(body).to include('data-location-type="address"')
    expect(body).to include('data-better_together--location-selector-target="newRecordBlock"')
    expect(body).to include('data-better_together--location-selector-target="cancelNewRecordButton"')
    expect(body).to match(/<legend[^>]*>\s*New address/)
  end

  it 'has no inline Building creation and no legacy "+ New" anchors' do # rubocop:disable RSpec/MultipleExpectations
    get "/#{I18n.default_locale}/events/new"

    body = decoded_body
    expect(body).not_to include('data-location-type="building"')
    expect(body).not_to include('better_together--location-selector#showNewRecord')
    expect(body).not_to include('data-better_together--location-selector-target="newRecordButton"')
  end
end

# frozen_string_literal: true

# A billing screen's save sends the steward back to that screen. Sent from inside a billing tab frame it is the
# screen's own path; sent from anywhere else it is the host billing page with the tab open (and, for a screen
# that is not the tab's first, the screen named in billing_path). This matcher accepts either.
RSpec::Matchers.define :redirect_to_billing_screen do |expected_path|
  match do |response|
    next false unless response.redirect?

    location = URI.parse(response.location)
    expected = URI.parse(expected_path.to_s)
    next true if location.path == expected.path && location.query == expected.query

    next false unless location.path.end_with?('/host/billing')

    asked = Rack::Utils.parse_query(location.query.to_s)['billing_path']
    asked.nil? ? location.fragment.to_s.start_with?('billing-pane-') : asked == [expected.path, expected.query].compact.join('?')
  end

  failure_message { |response| "expected a redirect to the billing screen #{expected_path}, got #{response.location.inspect}" }
end

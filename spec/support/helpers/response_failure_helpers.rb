# frozen_string_literal: true

# Failure detail for request specs that expect a redirect after a create. A 422 re-render
# otherwise fails with only the status code, hiding which validation rejected the record.
module ResponseFailureHelpers # :nodoc:
  def response_failure_detail
    record = controller.view_assigns.values.find { |value| value.respond_to?(:errors) && value.errors.any? }
    errors = record ? record.errors.full_messages.to_sentence : 'no record with errors assigned'
    "status #{response.status}, #{record.class.name}: #{errors}"
  end
end

RSpec.configure do |config|
  config.include ResponseFailureHelpers, type: :request
end

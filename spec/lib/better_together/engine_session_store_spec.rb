# frozen_string_literal: true

require 'rails_helper'

# A host app that loads the engine must keep Rails' own default session store. An engine initializer
# that sets `session_store :disabled` marks the store as configured, so Rails skips its default
# cookie store and every Devise/OmniAuth request fails with a missing-session error.
RSpec.describe 'Engine session store configuration' do # rubocop:todo RSpec/DescribeClass
  it 'does not disable the session store from any engine initializer' do
    offenders = BetterTogether::Engine.root.glob('config/initializers/**/*.rb').select do |file|
      file.read.match?(/session_store\s*\(?\s*:disabled/)
    end

    expect(offenders).to be_empty
  end
end

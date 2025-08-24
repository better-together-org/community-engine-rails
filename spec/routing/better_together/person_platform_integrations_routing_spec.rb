# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::PersonPlatformIntegrationsController do
  describe 'routing' do
    # rubocop:todo RSpec/RepeatedExample
    it 'routes to #index' do # rubocop:todo RSpec/NoExpectationExample, RSpec/RepeatedExample
      # expect(get: '/better_together/authorizations').to route_to('better_together/authorizations#index')
    end
    # rubocop:enable RSpec/RepeatedExample

    # rubocop:todo RSpec/RepeatedExample
    it 'routes to #new' do # rubocop:todo RSpec/NoExpectationExample, RSpec/RepeatedExample
      # expect(get: '/better_together/authorizations/new').to route_to('better_together/authorizations#new')
    end
    # rubocop:enable RSpec/RepeatedExample

    # rubocop:todo RSpec/RepeatedExample
    it 'routes to #show' do # rubocop:todo RSpec/NoExpectationExample, RSpec/RepeatedExample
      # rubocop:todo Layout/LineLength
      # expect(get: '/better_together/authorizations/1').to route_to('better_together/authorizations#show', id: '1')
      # rubocop:enable Layout/LineLength
    end
    # rubocop:enable RSpec/RepeatedExample

    # rubocop:todo RSpec/RepeatedExample
    it 'routes to #edit' do # rubocop:todo RSpec/NoExpectationExample, RSpec/RepeatedExample
      # rubocop:todo Layout/LineLength
      # expect(get: '/better_together/authorizations/1/edit').toroute_to('better_together/authorizations#edit', id: '1')
      # rubocop:enable Layout/LineLength
    end
    # rubocop:enable RSpec/RepeatedExample

    # rubocop:todo RSpec/RepeatedExample
    it 'routes to #create' do # rubocop:todo RSpec/NoExpectationExample, RSpec/RepeatedExample
      # expect(post: '/better_together/authorizations').to route_to('better_together/authorizations#create')
    end
    # rubocop:enable RSpec/RepeatedExample

    # rubocop:todo RSpec/RepeatedExample
    it 'routes to #update via PUT' do # rubocop:todo RSpec/NoExpectationExample, RSpec/RepeatedExample
      # rubocop:todo Layout/LineLength
      # expect(put: '/better_together/authorizations/1').to route_to('better_together/authorizations#update', id: '1')
      # rubocop:enable Layout/LineLength
    end
    # rubocop:enable RSpec/RepeatedExample

    # rubocop:todo RSpec/RepeatedExample
    it 'routes to #update via PATCH' do # rubocop:todo RSpec/NoExpectationExample, RSpec/RepeatedExample
      # rubocop:todo Layout/LineLength
      # expect(patch: '/better_together/authorizations/1').to route_to('better_together/authorizations#update', id: '1')
      # rubocop:enable Layout/LineLength
    end
    # rubocop:enable RSpec/RepeatedExample

    # rubocop:todo RSpec/RepeatedExample
    it 'routes to #destroy' do # rubocop:todo RSpec/NoExpectationExample, RSpec/RepeatedExample
      # rubocop:todo Layout/LineLength
      # expect(delete: '/better_together/authorizations/1').toroute_to('better_together/authorizations#destroy',id: '1')
      # rubocop:enable Layout/LineLength
    end
    # rubocop:enable RSpec/RepeatedExample
  end
end

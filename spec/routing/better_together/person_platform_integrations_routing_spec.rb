# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::PersonPlatformIntegrationsController do
  describe 'routing' do
    it 'routes to #index' do
      # expect(get: '/better_together/authorizations').to route_to('better_together/authorizations#index')
    end

    it 'routes to #new' do
      # expect(get: '/better_together/authorizations/new').to route_to('better_together/authorizations#new')
    end

    it 'routes to #show' do
      # expect(get: '/better_together/authorizations/1').to route_to('better_together/authorizations#show', id: '1')
    end

    it 'routes to #edit' do
      # expect(get: '/better_together/authorizations/1/edit').toroute_to('better_together/authorizations#edit', id: '1')
    end

    it 'routes to #create' do
      # expect(post: '/better_together/authorizations').to route_to('better_together/authorizations#create')
    end

    it 'routes to #update via PUT' do
      # expect(put: '/better_together/authorizations/1').to route_to('better_together/authorizations#update', id: '1')
    end

    it 'routes to #update via PATCH' do
      # expect(patch: '/better_together/authorizations/1').to route_to('better_together/authorizations#update', id: '1')
    end

    it 'routes to #destroy' do
      # expect(delete: '/better_together/authorizations/1').toroute_to('better_together/authorizations#destroy',id: '1')
    end
  end
end

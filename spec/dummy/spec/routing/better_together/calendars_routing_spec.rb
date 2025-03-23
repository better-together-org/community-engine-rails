# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::CalendarsController, type: :routing do # rubocop:todo Metrics/BlockLength
  describe 'routing' do
    it 'routes to #index' do
      # expect(get: '/better_together/calendars').to route_to('better_together/calendars#index')
    end

    it 'routes to #new' do
      # expect(get: '/better_together/calendars/new').to route_to('better_together/calendars#new')
    end

    it 'routes to #show' do
      # expect(get: '/better_together/calendars/1').to route_to('better_together/calendars#show', id: '1')
    end

    it 'routes to #edit' do
      # expect(get: '/better_together/calendars/1/edit').to route_to('better_together/calendars#edit', id: '1')
    end

    it 'routes to #create' do
      # expect(post: '/better_together/calendars').to route_to('better_together/calendars#create')
    end

    it 'routes to #update via PUT' do
      # expect(put: '/better_together/calendars/1').to route_to('better_together/calendars#update', id: '1')
    end

    it 'routes to #update via PATCH' do
      # expect(patch: '/better_together/calendars/1').to route_to('better_together/calendars#update', id: '1')
    end

    it 'routes to #destroy' do
      # expect(delete: '/better_together/calendars/1').to route_to('better_together/calendars#destroy', id: '1')
    end
  end
end

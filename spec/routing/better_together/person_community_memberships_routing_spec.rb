# frozen_string_literal: true

require 'rails_helper'

module BetterTogether
  RSpec.describe PersonCommunityMembershipsController, type: :routing do
    describe 'routing' do
      it 'routes to #index' do
        # rubocop:todo Layout/LineLength
        expect(get: '/bt/host/person_community_memberships').to route_to('better_together/person_community_memberships#index')
        # rubocop:enable Layout/LineLength
      end

      it 'routes to #new' do
        # rubocop:todo Layout/LineLength
        expect(get: '/bt/host/person_community_memberships/new').to route_to('better_together/person_community_memberships#new')
        # rubocop:enable Layout/LineLength
      end

      it 'routes to #show' do
        # rubocop:todo Layout/LineLength
        # expect(get: "/bt/host/person_community_memberships/1").to route_to("better_together/person_community_memberships#show", id: "1")
        # rubocop:enable Layout/LineLength
      end

      it 'routes to #edit' do
        # rubocop:todo Layout/LineLength
        # expect(get: "/bt/host/person_community_memberships/1/edit").to route_to("better_together/person_community_memberships#edit", id: "1")
        # rubocop:enable Layout/LineLength
      end

      it 'routes to #create' do
        # rubocop:todo Layout/LineLength
        expect(post: '/bt/host/person_community_memberships').to route_to('better_together/person_community_memberships#create')
        # rubocop:enable Layout/LineLength
      end

      it 'routes to #update via PUT' do
        # rubocop:todo Layout/LineLength
        # expect(put: "/bt/host/person_community_memberships/1").to route_to("better_together/person_community_memberships#update", id: "1")
        # rubocop:enable Layout/LineLength
      end

      it 'routes to #update via PATCH' do
        # rubocop:todo Layout/LineLength
        # expect(patch: "/bt/host/person_community_memberships/1").to route_to("better_together/person_community_memberships#update", id: "1")
        # rubocop:enable Layout/LineLength
      end

      it 'routes to #destroy' do
        # rubocop:todo Layout/LineLength
        # expect(delete: "/bt/host/person_community_memberships/1").to route_to("better_together/person_community_memberships#destroy", id: "1")
        # rubocop:enable Layout/LineLength
      end
    end
  end
end

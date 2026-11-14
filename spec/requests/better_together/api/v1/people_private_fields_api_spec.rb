# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'People API private attribute visibility', :no_auth do
  let(:viewer_user) { create(:better_together_user, :confirmed) }
  let(:viewer_headers) { api_auth_headers(viewer_user) }
  let(:manager_user) { create(:better_together_user, :confirmed, :platform_manager) }
  let(:manager_headers) { api_auth_headers(manager_user) }
  let(:owner_user) { create(:better_together_user, :confirmed) }
  let(:owner) { owner_user.person }
  let(:owner_headers) { api_auth_headers(owner_user) }
  let(:private_fields) do
    %w[email locale time_zone receive_messages_from_members federate_content
       notify_by_email show_conversation_details]
  end

  before { owner.update_column(:privacy, 'public') } # rubocop:disable Rails/SkipsModelValidations

  def attributes_for(headers, url)
    get url, headers: headers
    expect(response).to have_http_status(:ok)
    JSON.parse(response.body)['data']
  end

  it 'hides private attributes from other members on show', :aggregate_failures do
    data = attributes_for(viewer_headers, "/api/v1/people/#{owner.id}")

    expect(data['attributes']).to include('name' => owner.name)
    private_fields.each { |field| expect(data['attributes']).not_to have_key(field) }
  end

  it 'hides private attributes from other members on index', :aggregate_failures do
    get '/api/v1/people', headers: viewer_headers
    entry = JSON.parse(response.body)['data'].find { |row| row['id'] == owner.id }

    expect(entry).to be_present
    private_fields.each { |field| expect(entry['attributes']).not_to have_key(field) }
  end

  it 'does not let a sparse fieldset request recover private attributes', :aggregate_failures do
    data = attributes_for(viewer_headers, "/api/v1/people/#{owner.id}?fields[people]=name,email,locale")

    expect(data['attributes']).not_to have_key('email')
    expect(data['attributes']).not_to have_key('locale')
  end

  it 'shows private attributes to the person themself', :aggregate_failures do
    data = attributes_for(owner_headers, "/api/v1/people/#{owner.id}")

    expect(data['attributes']).to include('email' => owner.email, 'locale' => owner.locale)
    expect(data['attributes']).to have_key('federate_content')
  end

  it 'shows private attributes to a platform manager', :aggregate_failures do
    data = attributes_for(manager_headers, "/api/v1/people/#{owner.id}")

    expect(data['attributes']).to have_key('email')
    expect(data['attributes']).to have_key('time_zone')
  end

  it 'ignores filter[locale] so locale cannot be probed' do
    get "/api/v1/people?filter[locale]=#{owner.locale}", headers: viewer_headers

    expect(response).to have_http_status(:bad_request)
  end

  describe 'membership relationships' do
    let(:community) { create(:better_together_community) }

    before { create(:better_together_person_community_membership, member: owner, joinable: community) }

    it 'rejects include of membership relationships', :aggregate_failures do
      %w[person_community_memberships communities].each do |relationship|
        get "/api/v1/people/#{owner.id}?include=#{relationship}", headers: viewer_headers

        expect(response).to have_http_status(:bad_request)
      end
    end

    it 'omits membership relationships from other members', :aggregate_failures do
      get "/api/v1/people/#{owner.id}", headers: viewer_headers
      relationships = JSON.parse(response.body).dig('data', 'relationships') || {}

      expect(relationships).not_to have_key('communities')
      expect(relationships).not_to have_key('person_community_memberships')
    end

    it 'does not reveal private community membership through the relationship endpoint' do
      community.update_column(:privacy, 'private') # rubocop:disable Rails/SkipsModelValidations
      get "/api/v1/people/#{owner.id}/relationships/communities", headers: viewer_headers

      expect(response).to have_http_status(:not_found)
    end

    it 'lets the owner read their own relationship endpoint' do
      get "/api/v1/people/#{owner.id}/relationships/person_community_memberships", headers: owner_headers

      expect(response).to have_http_status(:ok)
    end

    it 'does not expose the owner\'s memberships through the nested endpoint' do
      get "/api/v1/people/#{owner.id}/person_community_memberships", headers: viewer_headers

      expect(JSON.parse(response.body)['data'] || []).to be_empty
    end
  end
end

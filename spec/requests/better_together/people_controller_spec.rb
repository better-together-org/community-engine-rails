# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'BetterTogether::PeopleController', :as_platform_manager do
  let(:locale) { I18n.default_locale }

  describe 'GET /:locale/.../host/p/:id' do
    let!(:person) { create(:better_together_person) }

    it 'renders show' do
      get better_together.person_path(locale:, id: person.slug)
      expect(response).to have_http_status(:ok)
    end

    it 'renders edit' do
      get better_together.edit_person_path(locale:, id: person.slug)
      expect(response).to have_http_status(:ok)
    end
  end

  describe 'PATCH /:locale/.../host/p/:id' do
    let!(:person) { create(:better_together_person) }

    # rubocop:todo RSpec/MultipleExpectations
    it 'updates name and redirects' do # rubocop:todo RSpec/ExampleLength, RSpec/MultipleExpectations
      # rubocop:enable RSpec/MultipleExpectations
      patch better_together.person_path(locale:, id: person.slug), params: {
        person: { name: 'Updated Name' }
      }
      expect(response).to have_http_status(:see_other)
      follow_redirect!
      expect(response).to have_http_status(:ok)
    end
  end

  describe 'GET /:locale/.../host/people' do
    context 'HTML format' do
      it 'renders index' do
        get better_together.people_path(locale:)
        expect(response).to have_http_status(:ok)
      end
    end

    context 'JSON format' do
      let!(:people) do
        create_list(:better_together_person, 5) do |person, index|
          person.update!(name: "Test User #{index + 1}")
        end
      end
      let!(:john_doe) { create(:better_together_person, name: 'John Doe') }
      let!(:jane_smith) { create(:better_together_person, name: 'Jane Smith') }
      let!(:bob_johnson) { create(:better_together_person, name: 'Bob Johnson') }

      it 'returns all people when no search query' do
        get better_together.people_path(locale:, format: :json)

        expect(response).to have_http_status(:ok)
        expect(response.content_type).to include('application/json')

        json_response = JSON.parse(response.body)
        expect(json_response).to be_an(Array)
        expect(json_response.length).to be >= 8 # At least 8 people (may include platform manager)

        # Verify our test people are included
        names = json_response.pluck('text')
        expect(names).to include('John Doe', 'Jane Smith', 'Bob Johnson')
      end

      it 'filters people by search query' do
        get better_together.people_path(locale:, format: :json, search: 'John')

        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)

        expect(json_response.length).to eq(2) # John Doe and Bob Johnson
        names = json_response.pluck('text')
        expect(names).to include('John Doe', 'Bob Johnson')
      end

      it 'returns empty array when no matches found' do
        get better_together.people_path(locale:, format: :json, search: 'NonexistentName')

        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        expect(json_response).to eq([])
      end

      it 'returns limited results (max 10)' do
        # Create more than 10 people with similar names
        create_list(:better_together_person, 15) do |person, index|
          person.update!(name: "SearchTest #{index + 1}")
        end

        get better_together.people_path(locale:, format: :json, search: 'SearchTest')

        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        expect(json_response.length).to eq(10) # Limited to 10 results
      end

      it 'returns correct JSON structure' do
        person = create(:better_together_person, name: 'Test Person')

        get better_together.people_path(format: :json, locale: I18n.default_locale)

        expect(response).to have_http_status(:ok)
        expect(response.content_type).to include('application/json')

        json_response = JSON.parse(response.body)
        expect(json_response).to be_an(Array)

        person_data = json_response.find { |p| p['value'] == person.id }
        expect(person_data).to be_present
        expect(person_data).to include(
          'text' => person.name,
          'value' => person.id,
          'data' => hash_including(
            'slug' => be_present,
            'locale' => be_present
          )
        )
      end

      it 'performs case-insensitive search' do
        get better_together.people_path(locale:, format: :json, search: 'jane')

        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)

        expect(json_response.length).to eq(1)
        expect(json_response.first['text']).to eq('Jane Smith')
      end

      it 'performs partial match search' do
        get better_together.people_path(locale:, format: :json, search: 'Smi')

        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)

        expect(json_response.length).to eq(1)
        expect(json_response.first['text']).to eq('Jane Smith')
      end

      it 'excludes people without email addresses from JSON responses' do
        # Create a person without an email address
        person_without_email = create(:better_together_person, name: 'No Email Person')
        allow(person_without_email).to receive(:email).and_return(nil)

        get better_together.people_path(locale:, format: :json)

        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)

        # Should not include the person without email
        person_names = json_response.pluck('text')
        expect(person_names).not_to include('No Email Person')
      end
    end
  end
end

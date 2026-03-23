# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'BetterTogether::ChecklistsController' do
  let(:locale) { I18n.default_locale }

  describe 'GET /checklists/:id' do
    let(:checklist) { create(:better_together_checklist, title: 'My List', privacy: 'public') }

    it 'shows a public checklist' do # rubocop:todo RSpec/MultipleExpectations
      get better_together.checklist_path(checklist, locale:)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('My List')
    end
  end

  describe 'CRUD actions as platform manager', :as_platform_manager do
    let(:locale) { I18n.default_locale }

    it 'creates a checklist' do # rubocop:todo RSpec/MultipleExpectations
      params = { checklist: { title_en: 'New Checklist', privacy: 'private' }, locale: locale }

      post better_together.checklists_path(locale: locale), params: params

      expect(response).to have_http_status(:found)
      checklist = BetterTogether::Checklist.order(:created_at).last
      expect(checklist.title).to eq('New Checklist')
    end

    # rubocop:todo RSpec/MultipleExpectations
    it 'updates a checklist' do # rubocop:todo RSpec/MultipleExpectations
      # rubocop:enable RSpec/MultipleExpectations
      checklist = create(:better_together_checklist,
                         creator: BetterTogether::User.find_by(email: 'manager@example.test').person)

      patch better_together.checklist_path(checklist, locale:),
            params: { checklist: { privacy: 'public', title_en: 'Updated' } }

      expect(response).to have_http_status(:found)
      follow_redirect!
      expect(response).to have_http_status(:ok)
      expect(checklist.reload.title).to eq('Updated')
    end

    it 'destroys an unprotected checklist' do # rubocop:todo RSpec/MultipleExpectations
      checklist = create(:better_together_checklist,
                         creator: BetterTogether::User.find_by(email: 'manager@example.test').person)

      delete better_together.checklist_path(checklist, locale:)

      expect(response).to have_http_status(:found)
      expect(BetterTogether::Checklist.where(id: checklist.id)).to be_empty
    end
  end

  describe 'authorization for update/destroy as creator' do
    # rubocop:todo RSpec/MultipleExpectations
    it 'allows creator to update their checklist' do # rubocop:todo RSpec/MultipleExpectations
      # rubocop:enable RSpec/MultipleExpectations
      user = create(:better_together_user, :confirmed, password: 'SecureTest123!@#')
      checklist = create(:better_together_checklist, creator: user.person)

      # sign in as that user
      login(user.email, 'SecureTest123!@#')

      patch better_together.checklist_path(checklist, locale: I18n.default_locale),
            params: { checklist: { title_en: 'Creator Update' } }

      expect(response).to have_http_status(:found)
      expect(checklist.reload.title).to eq('Creator Update')
    end
  end
end

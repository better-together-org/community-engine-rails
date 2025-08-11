# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Notifications', type: :request do
  let(:user) { create(:user, :confirmed) }

  describe 'GET /notifications' do
    it 'redirects unauthorized users' do
      login(user)
      allow_any_instance_of(BetterTogether::NotificationsPolicy).to receive(:index?).and_return(false)

      get better_together.notifications_path

      expect(response).to redirect_to(better_together.home_page_path)
    end
  end

  describe 'POST /notifications/mark_all_as_read' do
    it 'redirects unauthorized users' do
      login(user)
      allow_any_instance_of(BetterTogether::NotificationsPolicy).to receive(:mark_as_read?).and_return(false)

      post better_together.mark_all_as_read_notifications_path

      expect(response).to redirect_to(better_together.home_page_path)
    end
  end
end

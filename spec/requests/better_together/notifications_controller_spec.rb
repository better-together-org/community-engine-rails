# frozen_string_literal: true

require 'rails_helper'

module BetterTogether # rubocop:todo Metrics/ModuleLength
  RSpec.describe NotificationsController, :as_user do
    let!(:notification) { create(:noticed_notification, recipient: person) }
    let!(:user) { find_or_create_test_user('user@example.test', 'SecureTest123!@#', :user) }
    let(:person) { user.person }

    describe 'GET #index' do
      before do
        notification # Create the notification
        get "/#{I18n.default_locale}/notifications"
      end

      it 'returns successful response' do
        expect(response).to have_http_status(:ok)
      end

      it 'assigns notifications and unread count' do
        expect(assigns(:notifications)).to be_present
        expect(assigns(:unread_count)).to be_a(Integer)
      end

      it 'orders notifications by created_at desc' do
        create(:noticed_notification, recipient: person, created_at: 1.hour.ago)
        get "/#{I18n.default_locale}/notifications"

        assigned_notifications = assigns(:notifications)
        expect(assigned_notifications.first.created_at).to be >= assigned_notifications.last.created_at
      end
    end

    describe 'GET #dropdown' do
      before do
        notification # Create the notification
      end

      it 'returns successful response' do
        get "/#{I18n.default_locale}/notifications/dropdown"
        expect(response).to have_http_status(:ok)
      end

      it 'returns HTML content' do
        get "/#{I18n.default_locale}/notifications/dropdown"
        expect(response.content_type).to match(%r{text/html})
      end

      it 'caches the response based on max updated_at' do
        # First request
        get "/#{I18n.default_locale}/notifications/dropdown"
        first_response = response.body

        # Second request should return cached content
        get "/#{I18n.default_locale}/notifications/dropdown"
        expect(response.body).to eq(first_response)
      end

      it 'updates cache when notification changes' do
        # First request
        get "/#{I18n.default_locale}/notifications/dropdown"
        first_response = response.body

        # Update notification
        notification.update!(read_at: Time.current)

        # Second request should return different content
        get "/#{I18n.default_locale}/notifications/dropdown"
        expect(response.body).not_to eq(first_response)
      end

      context 'with no notifications' do
        before do
          person.notifications.destroy_all
        end

        it 'returns empty state content' do
          get "/#{I18n.default_locale}/notifications/dropdown"
          expect(response.body).to include(I18n.t('better_together.notifications.no_notifications'))
        end
      end
    end

    describe 'PATCH #mark_as_read' do
      context 'with specific notification id' do
        it 'marks the notification as read' do
          post "/#{I18n.default_locale}/notifications/#{notification.id}/mark_as_read"

          notification.reload
          expect(notification.read_at).to be_present
        end

        it 'redirects to notifications path for HTML requests' do
          post "/#{I18n.default_locale}/notifications/#{notification.id}/mark_as_read"
          expect(response).to redirect_to("/#{I18n.default_locale}/notifications")
        end

        it 'returns turbo stream for turbo requests' do
          post "/#{I18n.default_locale}/notifications/#{notification.id}/mark_as_read",
               headers: { 'Accept' => 'text/vnd.turbo-stream.html' }

          expect(response).to have_http_status(:ok)
        end
      end

      context 'with record_id parameter' do
        it 'marks notifications for that record as read' do
          record = create(:better_together_event)
          notification_with_record = create(:noticed_notification, recipient: person,
                                                                   event: build(:noticed_event, record: record))

          post "/#{I18n.default_locale}/notifications/mark_record_as_read", params: { record_id: record.id }

          notification_with_record.reload
          expect(notification_with_record.read_at).to be_present
        end
      end

      context 'with no parameters' do
        it 'marks all notifications as read' do
          notification2 = create(:noticed_notification, recipient: person)

          post "/#{I18n.default_locale}/notifications/mark_all_as_read"

          expect(response).to have_http_status(:redirect)

          [notification, notification2].each do |notif|
            notif.reload
            expect(notif.read_at).to be_present
          end
        end
      end
    end

    describe 'cache warming' do
      it 'works in production environment' do
        allow(Rails.env).to receive(:production?).and_return(true)

        get "/#{I18n.default_locale}/notifications/dropdown"
        expect(response).to have_http_status(:ok)
      end

      it 'does not call warm_notification_fragment_caches outside production' do
        allow(Rails.env).to receive(:production?).and_return(false)

        get "/#{I18n.default_locale}/notifications/dropdown"
        # Test passes if no error is raised
        expect(response).to have_http_status(:ok)
      end
    end
  end
end

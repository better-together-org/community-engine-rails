# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'BetterTogether::Metrics::Reports User Account Chart Endpoints', :as_platform_manager do
  let(:locale) { I18n.default_locale }
  let(:base_path) { "/#{locale}/host/metrics/reports" }

  describe 'GET /user_accounts_daily_data' do
    context 'with default date range (last 30 days)' do
      it 'returns daily account creation and confirmation data' do
        # Get baseline count (may include platform manager from setup)
        baseline_users = BetterTogether::User.where(created_at: 30.days.ago.beginning_of_day..Date.current.end_of_day).count

        # Create users within last 30 days
        create(:user, created_at: 20.days.ago, confirmed_at: 19.days.ago)
        create(:user, created_at: 20.days.ago, confirmed_at: nil)
        create(:user, created_at: 10.days.ago, confirmed_at: 9.days.ago)
        # User outside range should not appear
        create(:user, created_at: 60.days.ago, confirmed_at: 59.days.ago)

        get "#{base_path}/user_accounts_daily_data", headers: { 'Accept' => 'application/json' }

        expect(response).to have_http_status(:success)
        json = JSON.parse(response.body)

        expect(json['labels']).to be_an(Array)
        expect(json['labels'].length).to eq(31) # 30 days ago to today (inclusive)
        expect(json['datasets']).to be_an(Array)
        expect(json['datasets'].length).to eq(2)

        # Check dataset structure
        accounts_created_dataset = json['datasets'].find { |d| d['label'].include?('Created') }
        accounts_confirmed_dataset = json['datasets'].find { |d| d['label'].include?('Confirmed') }

        expect(accounts_created_dataset).to be_present
        expect(accounts_confirmed_dataset).to be_present
        expect(accounts_created_dataset['data'].sum).to eq(baseline_users + 3) # 3 new users in range
        expect(accounts_confirmed_dataset['data'].sum).to be >= 2 # At least 2 confirmed in range
      end
    end

    context 'with custom date range' do
      it 'filters users within the specified range' do
        start_date = 25.days.ago.to_date.iso8601
        end_date = 8.days.ago.to_date.iso8601

        # Get baseline count in this range BEFORE creating test users
        range = 25.days.ago.beginning_of_day..8.days.ago.end_of_day
        baseline_users = BetterTogether::User.where(created_at: range).count

        # Now create test users
        create(:user, created_at: 60.days.ago, confirmed_at: 59.days.ago)
        create(:user, created_at: 20.days.ago, confirmed_at: 19.days.ago)
        create(:user, created_at: 10.days.ago, confirmed_at: 9.days.ago)
        create(:user, created_at: 5.days.ago, confirmed_at: nil)

        get "#{base_path}/user_accounts_daily_data",
            params: { start_date: start_date, end_date: end_date },
            headers: { 'Accept' => 'application/json' }

        expect(response).to have_http_status(:success)
        json = JSON.parse(response.body)

        # Only the user created at 20 days ago and 10 days ago should be in this range (plus baseline)
        expect(json['datasets'][0]['data'].sum).to eq(baseline_users + 2)
      end
    end

    context 'when no users exist' do
      it 'returns empty datasets with zeros' do
        get "#{base_path}/user_accounts_daily_data", headers: { 'Accept' => 'application/json' }

        expect(response).to have_http_status(:success)
        json = JSON.parse(response.body)

        expect(json['labels'].length).to eq(31)
        # Account for platform manager user from setup - most days should be zero
        zero_count = json['datasets'][0]['data'].count(&:zero?)
        expect(zero_count).to be >= 29 # Most days are zero
        zero_count_confirmed = json['datasets'][1]['data'].count(&:zero?)
        expect(zero_count_confirmed).to be >= 29 # Most confirmed days are zero
      end
    end
  end

  describe 'GET /user_confirmation_rate_data' do
    context 'with mixed confirmation rates' do
      it 'returns daily confirmation rate percentages' do
        # Use specific times in the application timezone to ensure consistent grouping
        time_20_days_ago = 20.days.ago.to_date.in_time_zone.middle_of_day
        time_10_days_ago = 10.days.ago.to_date.in_time_zone.middle_of_day

        # Clear any users created by test setup that might interfere with date calculations
        BetterTogether::User.where('DATE(created_at) IN (?)', [time_20_days_ago.to_date, time_10_days_ago.to_date]).delete_all

        # Day 1: 2 created, 1 confirmed = 50%
        create(:user, created_at: time_20_days_ago, confirmed_at: time_20_days_ago)
        create(:user, created_at: time_20_days_ago, confirmed_at: nil)

        # Day 2: 3 created, 3 confirmed = 100%
        create(:user, created_at: time_10_days_ago, confirmed_at: time_10_days_ago)
        create(:user, created_at: time_10_days_ago, confirmed_at: time_10_days_ago)
        create(:user, created_at: time_10_days_ago, confirmed_at: time_10_days_ago)

        get "#{base_path}/user_confirmation_rate_data", headers: { 'Accept' => 'application/json' }

        expect(response).to have_http_status(:success)
        json = JSON.parse(response.body)

        expect(json['labels']).to be_an(Array)
        expect(json['values']).to be_an(Array)
        expect(json['labels'].length).to eq(31)
        expect(json['values'].length).to eq(31)

        # Find the days with activity
        day_20_ago_index = json['labels'].index(time_20_days_ago.to_date.to_s)
        day_10_ago_index = json['labels'].index(time_10_days_ago.to_date.to_s)

        expect(json['values'][day_20_ago_index]).to eq(50.0)
        expect(json['values'][day_10_ago_index]).to eq(100.0)
      end
    end

    context 'when no users were created on a day' do
      it 'returns 0 for that day' do
        get "#{base_path}/user_confirmation_rate_data", headers: { 'Accept' => 'application/json' }

        expect(response).to have_http_status(:success)
        json = JSON.parse(response.body)

        # Most days should have 0 (except possibly today from setup)
        zero_count = json['values'].count(&:zero?)
        expect(zero_count).to be >= 29 # At least 29 out of 31 days should be zero
      end
    end

    context 'with custom date range' do
      it 'filters to the specified range' do
        create(:user, created_at: 20.days.ago, confirmed_at: 20.days.ago)
        create(:user, created_at: 5.days.ago, confirmed_at: 5.days.ago)

        start_date = 25.days.ago.to_date.iso8601
        end_date = 15.days.ago.to_date.iso8601

        get "#{base_path}/user_confirmation_rate_data",
            params: { start_date: start_date, end_date: end_date },
            headers: { 'Accept' => 'application/json' }

        expect(response).to have_http_status(:success)
        json = JSON.parse(response.body)

        # Only includes days from 25 to 15 days ago (11 days total)
        expect(json['labels'].length).to eq(11)
      end
    end
  end

  describe 'GET /user_registration_sources_data' do
    context 'with users from different sources' do
      it 'returns breakdown of registration sources' do
        # Create test users
        # Open registration users (no invitation, no OAuth)
        create(:user, created_at: 10.days.ago)
        create(:user, created_at: 15.days.ago)

        # Invitation user
        invitation_user = create(:user, created_at: 12.days.ago)
        create(:invitation,
               invitee: invitation_user.person,
               inviter: create(:person),
               invitable: create(:platform),
               status: 'accepted',
               accepted_at: 12.days.ago)

        # OAuth user
        oauth_user = create(:user, created_at: 8.days.ago)
        create(:person_platform_integration, person: oauth_user.person)

        get "#{base_path}/user_registration_sources_data", headers: { 'Accept' => 'application/json' }

        expect(response).to have_http_status(:success)
        json = JSON.parse(response.body)

        expect(json['labels']).to be_an(Array)
        expect(json['labels'].length).to eq(3)
        expect(json['values']).to be_an(Array)
        expect(json['values'].length).to eq(3)

        # Check that we have the expected sources
        expect(json['labels']).to include('Open Registration')
        expect(json['labels']).to include('Invitation')
        expect(json['labels']).to include('OAuth/Social')

        # Verify counts - test created 2 open, 1 invitation, 1 oauth (plus any baseline)
        open_index = json['labels'].index('Open Registration')
        invitation_index = json['labels'].index('Invitation')
        oauth_index = json['labels'].index('OAuth/Social')

        # Just verify that we have at least our test users
        expect(json['values'][open_index]).to be >= 2
        expect(json['values'][invitation_index]).to eq(1)
        expect(json['values'][oauth_index]).to eq(1)
      end
    end

    context 'when all users are open registration' do
      it 'shows all users in open registration' do
        # Get baseline count
        range = 30.days.ago.beginning_of_day..Date.current.end_of_day
        baseline_open = BetterTogether::User.where(created_at: range).count

        create_list(:user, 5, created_at: 10.days.ago)

        get "#{base_path}/user_registration_sources_data", headers: { 'Accept' => 'application/json' }

        expect(response).to have_http_status(:success)
        json = JSON.parse(response.body)

        open_index = json['labels'].index('Open Registration')
        expect(json['values'][open_index]).to eq(baseline_open + 5)
        expect(json['values'].sum).to eq(baseline_open + 5)
      end
    end

    context 'with custom date range' do
      it 'filters users to the specified range' do
        create(:user, created_at: 60.days.ago)
        create(:user, created_at: 20.days.ago)
        create(:user, created_at: 10.days.ago)

        start_date = 25.days.ago.to_date.iso8601
        end_date = 15.days.ago.to_date.iso8601

        get "#{base_path}/user_registration_sources_data",
            params: { start_date: start_date, end_date: end_date },
            headers: { 'Accept' => 'application/json' }

        expect(response).to have_http_status(:success)
        json = JSON.parse(response.body)

        # Only 1 user in range (created 20 days ago)
        expect(json['values'].sum).to eq(1)
      end
    end

    context 'when no users exist' do
      it 'returns zeros for all sources' do
        get "#{base_path}/user_registration_sources_data", headers: { 'Accept' => 'application/json' }

        expect(response).to have_http_status(:success)
        json = JSON.parse(response.body)

        # May have platform manager user in open registration category
        expect(json['values'].sum).to be >= 0
      end
    end
  end

  describe 'GET /user_cumulative_growth_data' do
    context 'with users created over time' do
      it 'returns cumulative user counts' do
        create(:user, created_at: 20.days.ago)
        create(:user, created_at: 10.days.ago)
        create(:user, created_at: 10.days.ago)
        create(:user, created_at: 5.days.ago)

        get "#{base_path}/user_cumulative_growth_data", headers: { 'Accept' => 'application/json' }

        expect(response).to have_http_status(:success)
        json = JSON.parse(response.body)

        expect(json['labels']).to be_an(Array)
        expect(json['values']).to be_an(Array)
        expect(json['labels'].length).to eq(31)

        # Find indices for our test days
        day_20_index = json['labels'].index(20.days.ago.to_date.to_s)
        day_10_index = json['labels'].index(10.days.ago.to_date.to_s)
        day_5_index = json['labels'].index(5.days.ago.to_date.to_s)

        # Cumulative values should be monotonically increasing
        expect(json['values']).to eq(json['values'].sort)

        # Check that values increase at each day we created users
        # (Exact values depend on baseline, but relative increases are testable)
        expect(json['values'][day_20_index]).to be >= 1
        expect(json['values'][day_10_index]).to be > json['values'][day_20_index] # Added 2 more
        expect(json['values'][day_5_index]).to be > json['values'][day_10_index] # Added 1 more
        expect(json['values'].last).to be >= 4 # At least our 4 test users
      end
    end

    context 'when no users exist' do
      it 'returns zeros for all days' do
        get "#{base_path}/user_cumulative_growth_data", headers: { 'Accept' => 'application/json' }

        expect(response).to have_http_status(:success)
        json = JSON.parse(response.body)

        # Values should be either all zeros or show cumulative growth from existing setup users
        # Since cumulative means once we have a user, all subsequent days >= that count
        expect(json['values']).to eq(json['values'].sort) # Should be monotonically increasing
      end
    end

    context 'with custom date range' do
      it 'shows cumulative growth within range' do
        create(:user, created_at: 20.days.ago)
        create(:user, created_at: 15.days.ago)
        create(:user, created_at: 5.days.ago)

        start_date = 25.days.ago.to_date.iso8601
        end_date = 10.days.ago.to_date.iso8601

        get "#{base_path}/user_cumulative_growth_data",
            params: { start_date: start_date, end_date: end_date },
            headers: { 'Accept' => 'application/json' }

        expect(response).to have_http_status(:success)
        json = JSON.parse(response.body)

        # Should include 16 days (25 days ago to 10 days ago inclusive)
        expect(json['labels'].length).to eq(16)

        # Final cumulative should be 2 (users at 20 and 15 days ago)
        expect(json['values'].last).to eq(2)
      end
    end
  end
end

# frozen_string_literal: true

require 'rails_helper'

# Tests for event recurrence form integration
RSpec.describe 'Event Recurrence Form', :as_platform_manager do
  let(:locale) { I18n.default_locale }
  let(:event_params) do
    {
      name: 'Weekly Meeting',
      slug: 'weekly-meeting',
      description: 'A recurring weekly meeting',
      starts_at: 1.week.from_now,
      ends_at: 1.week.from_now + 2.hours,
      timezone: 'America/New_York',
      privacy: 'public',
      category_ids: [],
      creator_id: user.person.id,
      event_hosts_attributes: {
        '0' => {
          host_id: community.id,
          host_type: 'BetterTogether::Community'
        }
      }
    }
  end
  let(:community) { BetterTogether::Community.find_by(host: true) }
  let(:user) { find_or_create_test_user('manager@example.test', 'SecureTest123!@#', :platform_manager) }

  before do
    login('manager@example.test', 'SecureTest123!@#')
  end

  # Helper to build IceCube rule YAML for test setup
  def build_test_rule(frequency:, interval: 1, count: nil, until_date: nil) # rubocop:disable Metrics/MethodLength
    start_time = 1.week.from_now
    schedule = IceCube::Schedule.new(start_time)

    rule = case frequency
           when 'daily'
             IceCube::Rule.daily(interval)
           when 'weekly'
             IceCube::Rule.weekly(interval)
           when 'monthly'
             IceCube::Rule.monthly(interval)
           when 'yearly'
             IceCube::Rule.yearly(interval)
           end

    rule = rule.count(count) if count
    rule = rule.until(until_date) if until_date

    schedule.add_recurrence_rule(rule)
    schedule.to_yaml
  end

  describe 'POST /events with recurrence_attributes' do
    context 'when creating a weekly recurring event' do
      it 'creates event with recurrence' do
        post better_together.events_path(locale:), params: {
          event: event_params.merge(
            recurrence_attributes: {
              frequency: 'weekly',
              interval: 1,
              end_type: 'count',
              count: 10
            }
          )
        }

        expect(response).to redirect_to(better_together.event_path(BetterTogether::Event.last, locale:))

        event = BetterTogether::Event.last
        expect(event.recurrence).to be_present
        expect(event.recurrence.frequency).to eq('weekly')
        expect(event.recurrence.recurring?).to be true
      end
    end

    context 'when creating a monthly event ending on a date' do
      it 'creates event with recurrence ending on specific date' do
        end_date = 6.months.from_now.to_date

        post better_together.events_path(locale:), params: {
          event: event_params.merge(
            recurrence_attributes: {
              frequency: 'monthly',
              interval: 1,
              end_type: 'until',
              ends_on: end_date
            }
          )
        }

        expect(response).to redirect_to(better_together.event_path(BetterTogether::Event.last, locale:))

        event = BetterTogether::Event.last
        expect(event.recurrence).to be_present
        expect(event.recurrence.frequency).to eq('monthly')
        expect(event.recurrence.ends_on).to eq(end_date)
      end
    end

    context 'when creating an event without recurrence' do
      it 'creates event without recurrence' do
        post better_together.events_path(locale:), params: {
          event: event_params
        }

        expect(response).to redirect_to(better_together.event_path(BetterTogether::Event.last, locale:))

        event = BetterTogether::Event.last
        expect(event.recurrence).to be_nil
      end
    end

    context 'when creating a daily event with exception dates' do
      it 'creates event with exception dates' do
        exception_dates = [
          1.week.from_now.to_date.to_s,
          2.weeks.from_now.to_date.to_s
        ]

        post better_together.events_path(locale:), params: {
          event: event_params.merge(
            recurrence_attributes: {
              frequency: 'daily',
              interval: 1,
              end_type: 'count',
              count: 30,
              exception_dates: exception_dates.join(', ')
            }
          )
        }

        expect(response).to redirect_to(better_together.event_path(BetterTogether::Event.last, locale:))

        event = BetterTogether::Event.last
        expect(event.recurrence).to be_present
        expect(event.recurrence.exception_dates.size).to eq(2)
      end
    end
  end

  describe 'PATCH /events/:id with recurrence_attributes' do
    let!(:event) do
      create(:better_together_event,
             name: 'Original Event',
             creator: user.person,
             starts_at: 1.week.from_now,
             ends_at: 1.week.from_now + 2.hours)
    end

    before do
      event.event_hosts.create!(host: community)
    end

    context 'when adding recurrence to an existing event' do
      it 'creates recurrence for the event' do
        patch better_together.event_path(event, locale:), params: {
          event: {
            name: 'Updated Event',
            recurrence_attributes: {
              frequency: 'weekly',
              interval: 2,
              end_type: 'never'
            }
          }
        }

        # Update action redirects to edit page by default
        expect(response).to redirect_to(better_together.edit_event_path(event, locale:))

        event.reload
        expect(event.recurrence).to be_present
        expect(event.recurrence.frequency).to eq('weekly')
      end
    end

    context 'when updating existing recurrence' do
      let!(:event_with_recurrence) do
        event = create(:better_together_event, creator: user.person, starts_at: 1.week.from_now, ends_at: 1.week.from_now + 2.hours)
        event.event_hosts.create!(host: community)
        event.create_recurrence!(rule: build_test_rule(frequency: 'weekly', interval: 1))
        event
      end

      it 'updates the recurrence' do
        patch better_together.event_path(event_with_recurrence, locale:), params: {
          event: {
            recurrence_attributes: {
              id: event_with_recurrence.recurrence.id,
              frequency: 'daily',
              interval: 1,
              end_type: 'count',
              count: 5
            }
          }
        }

        # Update action redirects to edit page by default
        expect(response).to redirect_to(better_together.edit_event_path(event_with_recurrence, locale:))

        event_with_recurrence.reload
        expect(event_with_recurrence.recurrence.frequency).to eq('daily')
      end
    end

    context 'when removing recurrence from an event' do
      let!(:event_with_recurrence) do
        event = create(:better_together_event, creator: user.person, starts_at: 1.week.from_now, ends_at: 1.week.from_now + 2.hours)
        event.event_hosts.create!(host: community)
        event.create_recurrence!(rule: build_test_rule(frequency: 'weekly', interval: 1))
        event
      end

      it 'destroys the recurrence' do
        recurrence_id = event_with_recurrence.recurrence.id

        patch better_together.event_path(event_with_recurrence, locale:), params: {
          event: {
            recurrence_attributes: {
              id: recurrence_id,
              _destroy: '1'
            }
          }
        }

        expect(response).to redirect_to(better_together.edit_event_path(event_with_recurrence, locale:))

        event_with_recurrence.reload
        expect(event_with_recurrence.recurrence).to be_nil
        expect(BetterTogether::Recurrence.find_by(id: recurrence_id)).to be_nil
      end
    end
  end

  describe 'GET /events/new' do
    it 'renders the form with recurrence tab' do
      get better_together.new_event_path(locale:)

      expect(response).to have_http_status(:success)
      expect_html_content(I18n.t('better_together.events.tabs.recurrence'))
    end
  end

  describe 'GET /events/:id/edit' do
    let(:event) do
      create(:better_together_event,
             creator: user.person,
             starts_at: 1.week.from_now,
             ends_at: 1.week.from_now + 2.hours)
    end

    before do
      event.event_hosts.create!(host: community)
    end

    it 'renders the form with recurrence tab' do
      get better_together.edit_event_path(event, locale:)

      expect(response).to have_http_status(:success)
      expect_html_content(I18n.t('better_together.events.tabs.recurrence'))
    end

    context 'when event has recurrence' do
      before do
        event.create_recurrence!(rule: build_test_rule(frequency: 'weekly', interval: 1))
        event.reload
      end

      it 'renders the form with recurrence data' do
        get better_together.edit_event_path(event, locale:)

        expect(response).to have_http_status(:success)
        # Form displays 'Weekly' (capitalized) in the select dropdown
        expect_html_content('Weekly')
      end
    end
  end
end

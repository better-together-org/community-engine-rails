# frozen_string_literal: true

require 'rails_helper'

# Tests for event recurrence form integration
RSpec.describe 'Event Recurrence Form', :as_platform_manager do
  # Freeze time for consistent recurrence calculations
  before do
    travel_to(Time.zone.parse('2026-02-15 10:00:00'))
    login('manager@example.test', 'SecureTest123!@#')
    [privacy_policy, terms_of_service, code_of_conduct, content_publishing_agreement].each do |agreement|
      BetterTogether::AgreementParticipant.find_or_create_by!(participant: user.person, agreement: agreement) do |participant|
        participant.person = user.person
        participant.accepted_at = Time.current
      end
    end
  end

  let(:locale) { I18n.default_locale }
  let!(:community) { BetterTogether::Community.find_by(host: true) }
  let!(:user) { find_or_create_test_user('manager@example.test', 'SecureTest123!@#', :platform_manager) }
  let!(:privacy_policy) { BetterTogether::Agreement.find_or_create_by!(identifier: 'privacy_policy') }
  let!(:terms_of_service) { BetterTogether::Agreement.find_or_create_by!(identifier: 'terms_of_service') }
  let!(:code_of_conduct) { BetterTogether::Agreement.find_or_create_by!(identifier: 'code_of_conduct') }
  let!(:content_publishing_agreement) do
    BetterTogether::Agreement.find_or_create_by!(identifier: BetterTogether::PublicVisibilityGate::AGREEMENT_IDENTIFIER)
  end
  let(:starts_at) { Time.zone.parse('2026-02-22 10:00:00') }
  let(:ends_at) { Time.zone.parse('2026-02-22 12:00:00') }
  let(:event_params) do
    {
      name: 'Weekly Meeting',
      slug: 'weekly-meeting',
      starts_at: starts_at.iso8601,
      timezone: 'America/New_York',
      privacy: 'public',
      creator_id: user.person.id,
      category_ids: []
    }
  end

  # Helper to build IceCube rule YAML for test setup
  def build_test_rule(frequency:, interval: 1, count: nil, until_date: nil, weekdays: nil, start_time: nil) # rubocop:disable Metrics/MethodLength, Metrics/ParameterLists, Metrics/AbcSize, Metrics/CyclomaticComplexity
    start_time ||= Time.zone.parse('2026-02-22 10:00:00') # Explicit time
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

    Array(weekdays).each { |day| rule = rule.day(day) }
    rule = rule.count(count) if count
    rule = rule.until(until_date) if until_date

    schedule.add_recurrence_rule(rule)
    schedule.to_yaml
  end

  describe 'POST /events with recurrence_attributes' do
    context 'when creating a weekly recurring event' do
      it 'creates event with recurrence', :aggregate_failures do
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
      it 'creates event with recurrence ending on specific date', :aggregate_failures do
        end_date = Date.parse('2026-08-15') # Explicit date

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
      it 'creates event with exception dates', :aggregate_failures do
        exception_dates = [
          '2026-02-22', # Explicit dates
          '2026-03-01'
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

    context 'when creating a daily event with exception dates submitted as an array (current form UI)' do
      it 'creates event with exception dates', :aggregate_failures do
        post better_together.events_path(locale:), params: {
          event: event_params.merge(
            recurrence_attributes: {
              frequency: 'daily',
              interval: 1,
              end_type: 'count',
              count: 30,
              exception_dates: %w[2026-02-22 2026-03-01]
            }
          )
        }

        expect(response).to redirect_to(better_together.event_path(BetterTogether::Event.last, locale:))

        event = BetterTogether::Event.last
        expect(event.recurrence).to be_present
        expect(event.recurrence.exception_dates).to contain_exactly(Date.parse('2026-02-22'), Date.parse('2026-03-01'))
      end
    end

    context 'when an exception date cannot be parsed' do
      it 'does not silently drop it — it blocks the save with a validation error' do
        expect do
          post better_together.events_path(locale:), params: {
            event: event_params.merge(
              recurrence_attributes: {
                frequency: 'daily',
                interval: 1,
                end_type: 'count',
                count: 30,
                exception_dates: %w[2026-02-22 not-a-real-date]
              }
            )
          }
        end.not_to change(BetterTogether::Event, :count)

        expect(response).to have_http_status(:unprocessable_content)
        expect_html_content('could not be understood')
      end
    end
  end

  describe 'PATCH /events/:id with recurrence_attributes' do
    let!(:event) do
      create(:better_together_event,
             name: 'Original Event',
             creator: user.person,
             starts_at: Time.zone.parse('2026-02-22 10:00:00'), # Explicit time
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

    context 'when event has a weekly recurrence with specific weekdays' do
      before do
        # Monday and Wednesday, matching build_test_rule's default anchor of
        # 2026-02-22 (a Sunday) so the rule genuinely restricts to those days
        # rather than defaulting to the anchor's own weekday.
        event.create_recurrence!(rule: build_test_rule(frequency: 'weekly', weekdays: %i[monday wednesday]))
        event.reload
      end

      it 'pre-checks exactly the weekdays the recurrence actually has configured' do
        # Regression test for the Symbol-vs-Integer mismatch: Recurrence#weekdays
        # returns Symbols, but the edit form's checkboxes compare against
        # Integer indices — previously this meant every checkbox rendered
        # unchecked regardless of what was actually saved.
        get better_together.edit_event_path(event, locale:)

        expect(response).to have_http_status(:success)
        fragment = Nokogiri::HTML::DocumentFragment.parse(response.body)
        checked_values = fragment.css('input[type="checkbox"][name="event[recurrence_attributes][weekdays][]"][checked]')
                                 .map { |node| node['value'] }

        expect(checked_values).to contain_exactly('1', '3') # Monday, Wednesday
      end
    end
  end

  describe 'end_type selected without its paired value' do
    context 'when end_type is "until" but ends_on is blank' do
      it 'does not silently save as never-ending — it reports a validation error' do
        expect do
          post better_together.events_path(locale:), params: {
            event: event_params.merge(
              recurrence_attributes: {
                frequency: 'weekly',
                interval: 1,
                end_type: 'until',
                ends_on: ''
              }
            )
          }
        end.not_to change(BetterTogether::Event, :count)

        expect(response).to have_http_status(:unprocessable_content)
        expect_html_content('must be set when "On date" is selected')
      end
    end

    context 'when end_type is "count" but count is blank' do
      it 'does not silently save as never-ending — it reports a validation error' do
        expect do
          post better_together.events_path(locale:), params: {
            event: event_params.merge(
              recurrence_attributes: {
                frequency: 'weekly',
                interval: 1,
                end_type: 'count',
                count: ''
              }
            )
          }
        end.not_to change(BetterTogether::Event, :count)

        expect(response).to have_http_status(:unprocessable_content)
        expect_html_content('must be set when "After occurrences" is selected')
      end
    end
  end

  describe 'recurrence anchor timezone correctness' do
    context 'when creating an event with a non-UTC timezone and a recurrence in the same request' do
      it 'anchors the recurrence to the event-timezone-correct start time, not a UTC misparse' do
        # America/St_Johns is UTC-03:30 (NDT) — chosen because a naive
        # Time.zone.parse (ignoring the submitted timezone) would anchor the
        # schedule 3.5 hours off from the event's actual local start time.
        post better_together.events_path(locale:), params: {
          event: event_params.merge(
            timezone: 'America/St_Johns',
            starts_at: '2026-03-02T09:00:00',
            recurrence_attributes: {
              frequency: 'weekly',
              interval: 1,
              end_type: 'count',
              count: 4
            }
          )
        }

        expect(response).to redirect_to(better_together.event_path(BetterTogether::Event.last, locale:))

        event = BetterTogether::Event.last
        expected_start = ActiveSupport::TimeZone['America/St_Johns'].parse('2026-03-02T09:00:00')

        expect(event.recurrence.schedule.start_time).to eq(expected_start)
      end
    end

    context 'when updating both starts_at and recurrence in the same request' do
      let!(:event) do
        create(:better_together_event,
               creator: user.person,
               timezone: 'America/St_Johns',
               starts_at: Time.zone.parse('2026-02-22 10:00:00'),
               ends_at: Time.zone.parse('2026-02-22 12:00:00'))
      end

      before { event.event_hosts.create!(host: community) }

      it 'anchors the recurrence to the newly submitted starts_at, not the stale persisted one' do
        new_start = '2026-03-09T15:00:00'

        patch better_together.event_path(event, locale:), params: {
          event: {
            starts_at: new_start,
            timezone: 'America/St_Johns',
            recurrence_attributes: {
              frequency: 'weekly',
              interval: 1,
              end_type: 'never'
            }
          }
        }

        expect(response).to redirect_to(better_together.edit_event_path(event, locale:))

        event.reload
        expected_start = ActiveSupport::TimeZone['America/St_Johns'].parse(new_start)
        expect(event.recurrence.schedule.start_time).to eq(expected_start)
      end
    end
  end

  describe 'GET /events/recurrence_preview' do
    it 'renders upcoming occurrences for a valid, complete set of params' do
      get better_together.recurrence_preview_events_path(
        locale:, frequency: 'weekly', interval: 1, end_type: 'count', count: 3
      )

      expect(response).to have_http_status(:success)
      expect_element_count('#recurrence-preview-occurrences li', 3)
    end

    it 'reports an error instead of a false-empty result when end_type is selected without its paired value' do
      get better_together.recurrence_preview_events_path(
        locale:, frequency: 'weekly', interval: 1, end_type: 'until', ends_on: ''
      )

      expect(response).to have_http_status(:success)
      expect_element_count('#recurrence-preview-error', 1)
      expect_element_count('#recurrence-preview-occurrences', 0)
    end

    it 'renders the empty state when no frequency is selected yet' do
      get better_together.recurrence_preview_events_path(locale:, frequency: '')

      expect(response).to have_http_status(:success)
      expect_element_count('#recurrence-preview-empty', 1)
    end

    it 'includes a plain-English summary of the whole rule alongside the occurrence dates' do
      get better_together.recurrence_preview_events_path(
        locale:, frequency: 'weekly', interval: 2, weekdays: %w[1 3], end_type: 'count', count: 3
      )

      expect(response).to have_http_status(:success)
      expect_element_count('#recurrence-preview-summary', 1)
      expect_html_contents('Every 2 week(s) on Monday, Wednesday', '3 occurrences')
    end

    it 'omits the summary when the config is invalid rather than showing a misleading partial one' do
      get better_together.recurrence_preview_events_path(
        locale:, frequency: 'weekly', interval: 1, end_type: 'count', count: ''
      )

      expect(response).to have_http_status(:success)
      expect_element_count('#recurrence-preview-summary', 0)
    end

    # Authentication/authorization denial for this endpoint is covered at the
    # policy layer (EventPolicy#recurrence_preview? spec) rather than here —
    # this file's own top-level `before` block always logs in, and the
    # platform's privacy-gate behavior for anonymous requests is orthogonal
    # to what this endpoint itself needs to guarantee.
  end
end

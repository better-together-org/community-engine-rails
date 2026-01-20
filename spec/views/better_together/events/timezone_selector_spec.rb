# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'better_together/events/_event_datetime_fields.html.erb' do
  let(:platform) { BetterTogether::Platform.host }
  let(:user) { create(:better_together_user, :confirmed) }
  let(:person) { user.person }
  let(:event) { build(:better_together_event, timezone: 'America/New_York') }

  before do
    configure_host_platform

    # Update platform timezone
    platform.update!(time_zone: 'America/Toronto')

    # Assign view helpers
    assign(:event, event)
    allow(view).to receive_messages(current_user: user, current_person: person)
  end

  def render_partial_with_form
    render template: 'better_together/events/_form', locals: { event: event }
  end

  describe 'timezone selector' do
    context 'when creating a new event' do
      it 'displays timezone selector above datetime fields' do
        render_partial_with_form

        expect(rendered).to have_selector('[data-controller*="better_together--event-timezone"]')
      end

      it 'includes label for timezone selector' do
        render_partial_with_form

        expect(rendered).to have_selector('label', text: /time.*zone/i)
      end

      it 'defaults to user timezone when user has timezone preference' do
        person.update!(time_zone: 'America/Los_Angeles')

        render_partial_with_form

        expect(rendered).to include('America/Los_Angeles')
      end

      it 'defaults to platform timezone when user has no preference' do
        person.update!(time_zone: nil)

        render_partial_with_form

        expect(rendered).to include('America/Toronto')
      end

      it 'falls back to UTC when neither user nor platform have timezone' do
        person.update!(time_zone: nil)
        platform.update!(time_zone: nil)

        render_partial_with_form

        expect(rendered).to include('UTC')
      end
    end

    context 'when editing existing event' do
      let(:event) { create(:better_together_event, timezone: 'Europe/London') }

      it 'shows event timezone as selected value' do
        render_partial_with_form

        expect(rendered).to include('Europe/London')
      end
    end

    context 'accessibility' do
      it 'has accessible form controls' do
        render_partial_with_form

        # Timezone selector should have label
        expect(rendered).to have_selector('label[for*="timezone"]')

        # Should use semantic form elements
        expect(rendered).to have_selector('select[name*="timezone"]')
      end

      it 'includes help text explaining timezone selection' do
        render_partial_with_form

        expect(rendered).to have_selector('.form-text, .help-text, small')
      end
    end
  end

  describe 'current time display in selected timezone' do
    it 'shows current time in selected timezone' do
      render_partial_with_form

      # Should have a target for displaying current time
      expect(rendered).to have_selector('[data-better_together--event-timezone-target*="currentTime"]')
    end
  end
end

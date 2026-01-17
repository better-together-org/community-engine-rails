# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'better_together/events/_event_datetime_fields.html.erb' do
  let(:platform) { create(:platform, host: true, time_zone: 'America/Toronto') }
  let(:user) { create(:user) }
  let(:person) { user.person }
  let(:event) { build(:event, timezone: 'America/New_York') }

  before do
    # Setup host platform and authentication
    allow(BetterTogether::Platform).to receive(:host).and_return(platform)
    allow(view).to receive_messages(current_user: user, current_person: person, policy: double(create?: true))

    # Stub form_with to yield the form builder
    form_builder = instance_double(ActionView::Helpers::FormBuilder,
                                   time_zone_select: '',
                                   datetime_field: '',
                                   number_field: '',
                                   label: '',
                                   object: event,
                                   errors: event.errors)

    allow(view).to receive(:form_with).and_yield(form_builder)
  end

  describe 'timezone selector' do
    context 'when creating a new event' do
      it 'displays timezone selector above datetime fields' do
        render partial: 'better_together/events/event_datetime_fields',
               locals: { form: form_for_event(event), event: event }

        expect(rendered).to have_selector('[data-controller*="better_together--event-timezone"]')
      end

      it 'includes label for timezone selector' do
        render partial: 'better_together/events/event_datetime_fields',
               locals: { form: form_for_event(event), event: event }

        expect(rendered).to have_selector('label', text: /time.*zone/i)
      end

      it 'defaults to user timezone when user has timezone preference' do
        person.update!(time_zone: 'America/Los_Angeles')

        render partial: 'better_together/events/event_datetime_fields',
               locals: { form: form_for_event(event), event: event }

        expect(rendered).to include('America/Los_Angeles')
      end

      it 'defaults to platform timezone when user has no preference' do
        person.update!(time_zone: nil)

        render partial: 'better_together/events/event_datetime_fields',
               locals: { form: form_for_event(event), event: event }

        expect(rendered).to include('America/Toronto')
      end

      it 'falls back to UTC when neither user nor platform have timezone' do
        person.update!(time_zone: nil)
        platform.update!(time_zone: nil)

        render partial: 'better_together/events/event_datetime_fields',
               locals: { form: form_for_event(event), event: event }

        expect(rendered).to include('UTC')
      end
    end

    context 'when editing existing event' do
      let(:event) { create(:event, timezone: 'Europe/London') }

      it 'shows event timezone as selected value' do
        render partial: 'better_together/events/event_datetime_fields',
               locals: { form: form_for_event(event), event: event }

        expect(rendered).to include('Europe/London')
      end
    end

    context 'accessibility' do
      it 'has accessible form controls' do
        render partial: 'better_together/events/event_datetime_fields',
               locals: { form: form_for_event(event), event: event }

        # Timezone selector should have label
        expect(rendered).to have_selector('label[for*="timezone"]')

        # Should use semantic form elements
        expect(rendered).to have_selector('select[name*="timezone"]')
      end

      it 'includes help text explaining timezone selection' do
        render partial: 'better_together/events/event_datetime_fields',
               locals: { form: form_for_event(event), event: event }

        expect(rendered).to have_selector('.form-text, .help-text, small')
      end
    end
  end

  describe 'current time display in selected timezone' do
    it 'shows current time in selected timezone' do
      render partial: 'better_together/events/event_datetime_fields',
             locals: { form: form_for_event(event), event: event }

      # Should have a target for displaying current time
      expect(rendered).to have_selector('[data-better_together--event-timezone-target*="currentTime"]')
    end
  end

  private

  def form_for_event(event_instance)
    view.form_with(model: event_instance, url: '#') do |f|
      return f
    end
  end
end

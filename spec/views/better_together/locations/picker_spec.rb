# frozen_string_literal: true

require 'rails_helper'

# The picker is shared by any form whose record has a has_one :location, so it is rendered here for a community
# (not an event) to show its ids come from the record, not from the events form.
RSpec.describe 'better_together/locations/_picker' do
  let(:community) { build(:better_together_community) }
  let(:address_policy) { instance_double(BetterTogether::AddressPolicy, create?: can_create) }
  let(:can_create) { true }

  before { view.extend(BetterTogether::LocationPickerHelper) }

  def render_picker(**locals)
    allow(view).to receive(:policy).and_return(address_policy)
    render inline: "<%= form_with(model: record, scope: :community, url: '#') { |f| " \
                   "render 'better_together/locations/picker', form: f, record: record, **extra } %>",
           locals: { record: community, extra: locals }
  end

  it 'keys its ids on the record and wires the Stimulus controllers', :aggregate_failures do
    render_picker

    expect(rendered).to have_css('select#community_location_picker[data-controller="better_together--slim-select"]')
    expect(rendered).to have_css('#community_location_picker_hint')
    expect(rendered).to have_css('fieldset#community_location_new_address[hidden]', visible: :all)
    expect(rendered).to have_css('input[name$="[location_id]"]', visible: :all)
  end

  it 'points the lookup at the shared endpoint' do
    render_picker

    expect(rendered).to include(CGI.escapeHTML('/locations/available'))
  end

  it 'takes label and hint overrides' do
    render_picker(label: 'Where it is', hint: 'Pick a place')

    expect(rendered).to have_css('label[for="community_location_picker"]', text: 'Where it is')
    expect(rendered).to have_css('#community_location_picker_hint', text: 'Pick a place')
  end

  context 'when the person cannot create addresses' do
    let(:can_create) { false }

    it 'leaves out the new address panel' do
      render_picker

      expect(rendered).not_to have_css('#community_location_new_address')
    end
  end
end

# frozen_string_literal: true

require 'rails_helper'

module BetterTogether
  RSpec.describe ContactDetailsHelper do
    let(:person) { create(:better_together_person) }
    let(:contact_detail) do
      detail = person.contact_detail || create(:contact_detail, contactable: person)
      detail.reload
    end

    before do
      configure_host_platform
      create(:email_address, contact_detail:, email: 'public-contact@example.test', privacy: 'public',
                             primary_flag: false, label: 'personal')
      create(:email_address, contact_detail:, email: 'private-contact@example.test', privacy: 'private',
                             primary_flag: false, label: 'work')
      person.reload
    end

    describe '#render_contact_details' do
      it 'renders real markup, not escaped tags, and hides private items by default', :aggregate_failures do
        html = helper.render_contact_details(person)

        expect(html).to include('<div class="name-and-role mb-3">')
        expect(html).not_to include('&lt;div')
        expect(html).to include('public-contact@example.test')
        expect(html).not_to include('private-contact@example.test')
      end

      it 'shows private items when asked' do
        expect(helper.render_contact_details(person, include_private: true)).to include('private-contact@example.test')
      end

      it 'renders the name and role in strong tags' do
        contact_detail.update!(name: 'City Hall', role: 'Front desk')

        expect(helper.render_contact_details(person.reload)).to include('<strong>City Hall</strong>, <strong>Front desk</strong>')
      end
    end

    describe '#render_contacts' do
      it 'hides private items by default' do
        html = helper.render_contacts(person)

        expect(html).to include('public-contact@example.test')
        expect(html).not_to include('private-contact@example.test')
      end

      it 'hides private items when include_private is explicitly false' do
        html = helper.render_contacts(person, include_private: false)

        expect(html).not_to include('private-contact@example.test')
      end

      it 'shows private items when include_private is true' do
        html = helper.render_contacts(person, include_private: true)

        expect(html).to include('public-contact@example.test')
        expect(html).to include('private-contact@example.test')
      end
    end

    describe '#render_contact' do
      it 'filters private items by default' do
        html = helper.render_contact(contact_detail)

        expect(html).not_to include('private-contact@example.test')
      end
    end
  end
end

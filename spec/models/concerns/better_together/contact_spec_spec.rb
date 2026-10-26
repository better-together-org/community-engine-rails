# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::ContactSpec do
  include RequestSpecHelper

  before { configure_host_platform }

  let(:community) { create(:better_together_community) }
  let(:spec) do
    { phone_numbers: [{ number: '709-630-0012', label: 'Box office' }],
      email_addresses: [{ email: 'info@rotaryartscentre.ca', label: 'General enquiries' }],
      website_links: [{ url: 'https://www.rotaryartscentre.ca/', label: 'Website' }],
      social_media_accounts: [{ platform_name: 'Facebook', handle: 'RotaryArtsCentre',
                                url: 'https://www.facebook.com/RotaryArtsCentre/' }],
      addresses: [{ line1: '5 Park Street', line2: 'Lower Level, Corner Brook City Hall', city_name: 'Corner Brook',
                    postal_code: 'A2H 2Y8', country_name: 'Canada', label: 'Main' }] }
  end

  def contact
    community.reload.contact_detail
  end

  it 'writes each kind with its custom label, public', :aggregate_failures do # rubocop:disable RSpec/ExampleLength
    community.update!(contact_spec: spec.to_json)

    expect(contact.phone_numbers.map { |p| [p.number, p.label, p.privacy] })
      .to eq([['709-630-0012', 'Box office', 'public']])
    expect(contact.email_addresses.pluck(:email, :label)).to eq([['info@rotaryartscentre.ca', 'General enquiries']])
    expect(contact.website_links.pluck(:url, :label)).to eq([['https://www.rotaryartscentre.ca/', 'Website']])
    expect(contact.social_media_accounts.pluck(:platform_name, :handle)).to eq([%w[Facebook RotaryArtsCentre]])
    expect(contact.addresses.map { |a| [a.line1, a.label] }).to eq([['5 Park Street', 'Main']])
  end

  it 'shows the custom label as written' do
    community.update!(contact_spec: spec.to_json)

    expect(contact.phone_numbers.first.display_label).to eq('Box office')
  end

  it 'changes nothing when the same spec is sent again', :aggregate_failures do
    community.update!(contact_spec: spec.to_json)
    ids = contact.phone_numbers.pluck(:id) + contact.addresses.pluck(:id)
    community.update!(contact_spec: spec.to_json)

    expect(contact.phone_numbers.pluck(:id) + contact.addresses.pluck(:id)).to eq(ids)
  end

  it 'replaces a kind that is present and leaves an absent kind alone', :aggregate_failures do
    community.update!(contact_spec: spec.to_json)
    community.update!(contact_spec: { phone_numbers: [{ number: '709-555-0100', label: 'Office' }] }.to_json)

    expect(contact.phone_numbers.pluck(:number)).to eq(['709-555-0100'])
    expect(contact.email_addresses.count).to eq(1)
  end

  it 'reuses the address the record is located at', :aggregate_failures do
    community.update!(address_spec: spec[:addresses].first.to_json)
    located = community.reload.location.location
    community.update!(contact_spec: spec.to_json)

    expect(contact.addresses).to eq([located])
    expect(BetterTogether::Address.where(line1: '5 Park Street').count).to eq(1)
  end

  it 'rejects invalid JSON and entries without their key', :aggregate_failures do
    community.contact_spec = 'nope'
    expect(community).not_to be_valid

    other = build(:better_together_community)
    other.contact_spec = { phone_numbers: [{ label: 'x' }] }.to_json
    expect(other).not_to be_valid
  end
end

# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Api::V1::EventResource, '.creatable_fields' do
  let(:resource) { described_class }

  it 'accepts the host and cover image fields on create and update', :aggregate_failures do
    %i[hosts status cover_image_data cover_image_filename attachment_block_ids].each do |field|
      expect(resource.creatable_fields({})).to include(field)
      expect(resource.updatable_fields({})).to include(field)
    end
  end

  it 'never returns the write-only image or session_of fields' do
    fields = resource.new(BetterTogether::Event.new, {}).fetchable_fields

    expect(fields).not_to include(:cover_image_data, :cover_image_filename, :attachment_block_ids)
  end

  describe 'naming hosts' do
    let(:community) { create(:better_together_community) }
    let(:person) { create(:better_together_person) }
    let(:user) { instance_double(BetterTogether::User, person:) }
    let(:specs) { [{ host_type: community.class.name, host_id: community.id }] }

    let(:name_hosts) do
      lambda do |value|
        resource.new(BetterTogether::Event.new, { current_user: user }).tap { |instance| instance.hosts = value }
      end
    end

    it 'allows hosts the person can host for, as a list or JSON', :aggregate_failures do
      allow(person).to receive_messages(valid_event_host_ids: [community.id, person.id], permitted_to?: false)

      expect(name_hosts.call(specs)._model.hosts).to eq(specs)
      expect(name_hosts.call(specs.to_json)._model.hosts).to eq(specs)
    end

    it 'allows a platform manager to name any host' do
      allow(person).to receive_messages(valid_event_host_ids: [], permitted_to?: true)

      expect(name_hosts.call(specs)._model.hosts).to eq(specs)
    end

    it 'refuses a host the person cannot host for' do
      allow(person).to receive_messages(valid_event_host_ids: [], permitted_to?: false)

      expect { name_hosts.call(specs) }.to raise_error(JSONAPI::Exceptions::InvalidFieldValue)
    end
  end

  describe 'status' do
    let(:name_status) do
      lambda do |value|
        resource.new(BetterTogether::Event.new, {}).tap { |instance| instance.status = value }
      end
    end

    it 'sets a known lifecycle status' do
      expect(name_status.call('confirmed')._model).to be_status_confirmed
    end

    it 'refuses an unknown status' do
      expect { name_status.call('published') }.to raise_error(JSONAPI::Exceptions::InvalidFieldValue)
    end
  end
end

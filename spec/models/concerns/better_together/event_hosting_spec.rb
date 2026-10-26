# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::EventHosting do
  include RequestSpecHelper

  before { configure_host_platform }

  let(:creator) { create(:better_together_person) }
  let(:community) { create(:better_together_community) }
  let(:other) { create(:better_together_community) }
  let(:event) { build(:better_together_event, creator:, event_hosts: []) }

  def spec(*hosts)
    hosts.map { |host| { host_type: host.class.name, host_id: host.id } }
  end

  it 'hosts the event by the community and not by the creator', :aggregate_failures do
    event.hosts = spec(community)
    event.save!

    expect(event.event_hosts.map(&:host)).to eq([community])
    expect(event.hosts).to eq(spec(community))
  end

  it 'supports several hosts of different types, from a JSON string', :aggregate_failures do
    event.hosts = spec(community, creator).to_json
    event.save!

    expect(event.reload.event_hosts.map(&:host)).to contain_exactly(community, creator)
  end

  it 'still defaults to the creator when no hosts are given' do
    event.save!

    expect(event.event_hosts.map(&:host)).to eq([creator])
  end

  it 'replaces the hosts on update, keeping the ones that stay', :aggregate_failures do
    event.update!(hosts: spec(community, other))
    kept = event.event_hosts.find { |h| h.host == community }.id

    event.update!(hosts: spec(community, creator))

    expect(event.reload.event_hosts.map(&:host)).to contain_exactly(community, creator)
    expect(event.event_hosts.map(&:id)).to include(kept)
  end

  [
    [{ host_type: 'BetterTogether::Community', host_id: 'missing' }],
    [{ host_type: 'BetterTogether::Event', host_id: 'any' }],
    []
  ].each do |bad|
    it "rejects the host list #{bad.inspect}", :aggregate_failures do
      event.hosts = bad

      expect(event).not_to be_valid
      expect(event.errors[:hosts]).to be_present
    end
  end
end

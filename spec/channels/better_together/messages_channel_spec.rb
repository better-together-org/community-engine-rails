# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::MessagesChannel do
  let(:person) { create(:person) }

  before do
    stub_connection(current_person: person)
  end

  it 'streams for the current person on subscribe' do
    subscribe
    expect(subscription).to be_confirmed
    expect(subscription).to have_stream_for(person)
  end

  it 'does not raise on unsubscribe' do
    subscribe
    expect { unsubscribe }.not_to raise_error
  end
end

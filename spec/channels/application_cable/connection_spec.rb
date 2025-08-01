# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ApplicationCable::Connection, type: :channel do
  let(:user) { create(:better_together_user) }

  it 'successfully connects for authenticated user' do
    env = { 'warden' => double('warden', user: user) }
    connect '/cable', env: env
    expect(connection.current_person).to eq(user.person)
  end

  it 'rejects connection for unauthenticated user' do
    env = { 'warden' => double('warden', user: nil) }
    expect { connect '/cable', env: env }.to raise_error(ActionCable::Connection::Authorization::UnauthorizedError)
  end
end

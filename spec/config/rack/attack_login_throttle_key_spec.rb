# frozen_string_literal: true

require 'rails_helper'

# P0-7: the login throttle must see Devise's user[email] and be scoped per host.
RSpec.describe 'Rack::Attack logins/email throttle key' do # rubocop:disable RSpec/DescribeClass
  let(:throttle) { Rack::Attack.throttles['logins/email'] }

  def key_for(host, params)
    env = Rack::MockRequest.env_for("http://#{host}/en/users/sign-in", method: 'POST', params:)
    throttle.block.call(Rack::Attack::Request.new(env))
  end

  it 'keys on the Devise nested user[email] param, normalised' do
    expect(key_for('a.example.test', 'user' => { 'email' => ' Person@Example.Test ' }))
      .to eq('a.example.test:person@example.test')
  end

  it 'still honours a bare email param' do
    expect(key_for('a.example.test', 'email' => 'p@example.test')).to eq('a.example.test:p@example.test')
  end

  it 'separates the same address on different platforms' do
    one = key_for('a.example.test', 'user' => { 'email' => 'p@example.test' })
    two = key_for('b.example.test', 'user' => { 'email' => 'p@example.test' })

    expect(one).not_to eq(two)
  end

  it 'does not throttle requests without an email' do
    expect(key_for('a.example.test', {})).to be_nil
  end
end

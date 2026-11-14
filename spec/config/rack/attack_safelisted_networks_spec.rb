# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Rack::Attack, '.safelisted_networks' do
  def request_from(ip)
    Rack::Attack::Request.new(Rack::MockRequest.env_for('/', 'REMOTE_ADDR' => ip))
  end

  def safelisted?(ip)
    described_class.safelists.fetch('allow trusted networks').matched_by?(request_from(ip))
  end

  around do |example|
    original = ENV.fetch('RACK_ATTACK_SAFELIST_NETWORKS', nil)
    ENV['RACK_ATTACK_SAFELIST_NETWORKS'] = '10.45.20.0/24, 142.93.157.196/32, not-a-cidr'
    example.run
  ensure
    original.nil? ? ENV.delete('RACK_ATTACK_SAFELIST_NETWORKS') : ENV['RACK_ATTACK_SAFELIST_NETWORKS'] = original
  end

  it 'safelists addresses inside a configured network and ignores invalid entries' do
    expect(described_class.safelisted_networks.size).to eq(2)
    expect(safelisted?('10.45.20.100')).to be_truthy
    expect(safelisted?('142.93.157.196')).to be_truthy
  end

  it 'does not safelist other addresses' do
    expect(safelisted?('203.0.113.9')).to be_falsey
  end

  it 'safelists nothing when the variable is unset' do
    ENV.delete('RACK_ATTACK_SAFELIST_NETWORKS')

    expect(safelisted?('142.93.157.196')).to be_falsey
  end
end

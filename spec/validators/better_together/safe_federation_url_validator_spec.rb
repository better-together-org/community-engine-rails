# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::SafeFederationUrlValidator do # rubocop:disable RSpec/SpecFilePathFormat
  # rubocop:todo Metrics/BlockLength
  subject(:validator) { described_class.new(attributes: [:host_url]) }

  let(:record) do
    Class.new do
      include ActiveModel::Validations
      attr_accessor :host_url
      validates :host_url, safe_federation_url: true
    end.new
  end

  def set_url(url)
    record.host_url = url
    record.validate
    record.errors[:host_url]
  end

  describe 'valid URLs' do # rubocop:disable RSpec/DescribedClass
    it 'accepts a public HTTPS URL' do
      expect(set_url('https://example.com')).to be_empty
    end

    it 'accepts a public HTTP URL' do
      expect(set_url('http://federation.example.org/api')).to be_empty
    end

    it 'accepts a public IP address' do
      expect(set_url('https://8.8.8.8')).to be_empty
    end

    it 'passes through blank values (allow_blank handled by caller)' do
      expect(set_url(nil)).to be_empty
    end
  end

  describe 'SSRF-dangerous URLs' do # rubocop:disable RSpec/DescribedClass
    it 'rejects loopback IP' do
      expect(set_url('https://127.0.0.1/')).not_to be_empty
    end

    it 'rejects RFC 1918 class A private IP' do
      expect(set_url('http://10.0.0.1/path')).not_to be_empty
    end

    it 'rejects RFC 1918 class B private IP' do
      expect(set_url('http://172.16.0.1/')).not_to be_empty
    end

    it 'rejects RFC 1918 class C private IP' do
      expect(set_url('https://192.168.1.100/')).not_to be_empty
    end

    it 'rejects AWS link-local metadata IP' do
      expect(set_url('http://169.254.169.254/latest/meta-data/')).not_to be_empty
    end

    it 'rejects IPv6 loopback' do
      expect(set_url('https://[::1]/')).not_to be_empty
    end

    it 'rejects URLs with embedded credentials' do
      expect(set_url('https://user:pass@example.com/')).not_to be_empty
    end
  end
  # rubocop:enable Metrics/BlockLength
end

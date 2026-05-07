# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::MediaUrlBuilder, type: :service do
  let(:attachment) { instance_double(ActiveStorage::Attached) }
  let(:route_helpers) { Rails.application.routes.url_helpers }

  describe '.proxy_path_for' do
    it 'forwards keyword arguments to rails_storage_proxy_path' do
      allow(route_helpers).to receive(:rails_storage_proxy_path).and_return('/rails/active_storage/proxy/test')

      described_class.proxy_path_for(attachment, disposition: 'attachment')

      expect(route_helpers).to have_received(:rails_storage_proxy_path).with(
        attachment,
        only_path: true,
        disposition: 'attachment'
      )
      expect(described_class.proxy_path_for(attachment, disposition: 'attachment')).to eq('/rails/active_storage/proxy/test')
    end
  end

  describe '.proxy_url_for' do
    it 'builds a same-origin URL when base_url is provided' do
      allow(described_class).to receive(:proxy_path_for).and_return('/rails/active_storage/proxy/test')

      described_class.proxy_url_for(attachment, base_url: 'https://communityengine.app', disposition: 'attachment')

      expect(described_class).to have_received(:proxy_path_for).with(
        attachment,
        disposition: 'attachment'
      )
      expect(
        described_class.proxy_url_for(attachment, base_url: 'https://communityengine.app', disposition: 'attachment')
      ).to eq('https://communityengine.app/rails/active_storage/proxy/test')
    end

    it 'forwards url_options and keyword arguments to rails_storage_proxy_url' do
      allow(route_helpers).to receive(:rails_storage_proxy_url).and_return(
        'https://communityengine.app/rails/active_storage/proxy/test'
      )

      described_class.proxy_url_for(
        attachment,
        url_options: { host: 'communityengine.app', protocol: 'https' },
        disposition: 'attachment'
      )

      expect(route_helpers).to have_received(:rails_storage_proxy_url).with(
        attachment,
        host: 'communityengine.app',
        protocol: 'https',
        disposition: 'attachment'
      )

      expect(
        described_class.proxy_url_for(
          attachment,
          url_options: { host: 'communityengine.app', protocol: 'https' },
          disposition: 'attachment'
        )
      ).to eq('https://communityengine.app/rails/active_storage/proxy/test')
    end

    it 'falls back to the proxy path when url_options has no host' do
      allow(described_class).to receive(:proxy_path_for).and_return('/rails/active_storage/proxy/test')
      allow(route_helpers).to receive(:rails_storage_proxy_url)

      expect(
        described_class.proxy_url_for(
          attachment,
          url_options: { locale: :en },
          disposition: 'attachment'
        )
      ).to eq('/rails/active_storage/proxy/test')

      expect(described_class).to have_received(:proxy_path_for).with(
        attachment,
        disposition: 'attachment'
      )
      expect(route_helpers).not_to have_received(:rails_storage_proxy_url)
    end

    it 'falls back to the proxy path when url_options is empty' do
      allow(described_class).to receive(:proxy_path_for).and_return('/rails/active_storage/proxy/test')
      allow(route_helpers).to receive(:rails_storage_proxy_url)

      expect(described_class.proxy_url_for(attachment, url_options: {}, disposition: 'attachment')).to eq(
        '/rails/active_storage/proxy/test'
      )

      expect(described_class).to have_received(:proxy_path_for).with(
        attachment,
        disposition: 'attachment'
      )
      expect(route_helpers).not_to have_received(:rails_storage_proxy_url)
    end
  end
end

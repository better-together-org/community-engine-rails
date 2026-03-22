# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::ShareButtonsHelper do
  let(:shareable_page) { create(:better_together_page, title: 'Test Page') }
  let(:shareable_post) { create(:better_together_post, title: 'Test Post') }
  let(:shareable_without_title) do
    instance_double(BetterTogether::Page, id: 'test-id', title: nil, name: nil)
  end

  before do
    allow(helper).to receive_messages(request: double(original_url: 'https://example.com/test'),
                                      better_together: double(metrics_shares_path: '/shares'))
  end

  describe '#share_buttons' do
    it 'renders share buttons for all default platforms' do
      result = helper.share_buttons(shareable: shareable_page)
      expect(result).to include('data-controller="better_together--share"')
      expect(result).to include('social-share-buttons')
    end

    it 'includes email platform by default' do
      result = helper.share_buttons(shareable: shareable_page)
      expect(result).to include('data-platform="email"')
    end

    it 'includes facebook platform by default' do
      result = helper.share_buttons(shareable: shareable_page)
      expect(result).to include('data-platform="facebook"')
    end

    it 'uses page title when shareable has title' do
      result = helper.share_buttons(shareable: shareable_page)
      expect(result).to include(shareable_page.title)
    end

    it 'uses post title when shareable has title' do
      result = helper.share_buttons(shareable: shareable_post)
      expect(result).to include(shareable_post.title)
    end

    it 'uses default title when shareable has no title or name' do
      result = helper.share_buttons(shareable: shareable_without_title)
      # Should render without errors even when shareable has no title or name
      expect(result).to include('social-share-buttons')
      expect(result).to include('data-shareable-id="test-id"')
    end

    it 'includes shareable type and id in data attributes' do
      result = helper.share_buttons(shareable: shareable_page)
      expect(result).to include('data-shareable-type')
      expect(result).to include('data-shareable-id')
    end

    it 'accepts custom platforms list' do
      result = helper.share_buttons(platforms: %i[email facebook], shareable: shareable_page)
      expect(result).to include('data-platform="email"')
      expect(result).to include('data-platform="facebook"')
    end
  end

  describe '#share_button_content' do
    it 'returns email icon for email platform' do
      result = helper.send(:share_button_content, :email)
      expect(result).to include('fa-envelope')
    end

    it 'returns facebook icon for facebook platform' do
      result = helper.send(:share_button_content, :facebook)
      expect(result).to include('fa-facebook')
    end

    it 'returns bluesky icon for bluesky platform' do
      result = helper.send(:share_button_content, :bluesky)
      expect(result).to include('fa-bluesky')
    end

    it 'returns linkedin icon for linkedin platform' do
      result = helper.send(:share_button_content, :linkedin)
      expect(result).to include('fa-linkedin')
    end

    it 'returns pinterest icon for pinterest platform' do
      result = helper.send(:share_button_content, :pinterest)
      expect(result).to include('fa-pinterest')
    end

    it 'returns reddit icon for reddit platform' do
      result = helper.send(:share_button_content, :reddit)
      expect(result).to include('fa-reddit')
    end

    it 'returns whatsapp icon for whatsapp platform' do
      result = helper.send(:share_button_content, :whatsapp)
      expect(result).to include('fa-whatsapp')
    end

    it 'returns default text for unknown platform' do
      result = helper.send(:share_button_content, :unknown)
      expect(result).to eq(I18n.t('better_together.share_buttons.share'))
    end
  end

  describe '#share_icon' do
    it 'returns email icon with fa-envelope' do
      result = helper.send(:share_icon, 'email')
      expect(result).to include('fa-envelope')
      expect(result).to include('fa-stack')
    end

    it 'returns facebook icon with fa-facebook' do
      result = helper.send(:share_icon, 'facebook')
      expect(result).to include('fa-facebook')
      expect(result).to include('fa-stack')
    end

    it 'includes background circle' do
      result = helper.send(:share_icon, 'email')
      expect(result).to include('fa-circle')
      expect(result).to include('fa-stack-2x')
    end

    it 'includes icon on top' do
      result = helper.send(:share_icon, 'email')
      expect(result).to include('fa-stack-1x')
    end

    it 'has role=img for accessibility' do
      result = helper.send(:share_icon, 'email')
      expect(result).to include('role="img"')
    end
  end
end

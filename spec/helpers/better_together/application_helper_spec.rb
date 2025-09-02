# frozen_string_literal: true

require 'rails_helper'

module BetterTogether
  RSpec.describe ApplicationHelper do
    describe '#robots_meta_tag' do
      it 'renders default robots meta tag' do # rubocop:todo RSpec/MultipleExpectations
        tag = helper.robots_meta_tag
        expect(tag).to include('name="robots"')
        expect(tag).to include('content="index,follow"')
      end

      it 'allows override via content_for' do
        view.content_for(:meta_robots, 'noindex,nofollow')
        tag = helper.robots_meta_tag
        expect(tag).to include('content="noindex,nofollow"')
      end
    end
  end
end

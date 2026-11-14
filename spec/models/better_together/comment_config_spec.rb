# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::CommentConfig do
  let(:post) { create(:post) }

  describe 'associations' do
    it 'belongs to a polymorphic commentable' do
      config = described_class.create!(commentable: post)
      expect(config.commentable).to eq(post)
    end
  end

  describe 'permission enum' do
    it 'defaults to inherit' do
      expect(described_class.new(commentable: post).permission).to eq('inherit')
    end

    it 'accepts community and disabled' do
      config = described_class.new(commentable: post, permission: 'community')
      expect(config).to be_valid
      config.permission = 'disabled'
      expect(config).to be_valid
    end

    it 'exposes prefixed query methods so they do not collide with the visibility enum' do
      config = described_class.new(commentable: post, permission: 'community')
      expect(config.permission_community?).to be true
      expect(config.permission_disabled?).to be false
    end
  end

  describe 'visibility enum' do
    it 'defaults to inherit' do
      expect(described_class.new(commentable: post).visibility).to eq('inherit')
    end

    it 'accepts community' do
      config = described_class.new(commentable: post, visibility: 'community')
      expect(config).to be_valid
    end

    it 'exposes prefixed query methods so they do not collide with the permission enum' do
      config = described_class.new(commentable: post, visibility: 'community')
      expect(config.visibility_community?).to be true
      expect(config.visibility_inherit?).to be false
    end
  end

  describe 'commentable_type validation' do
    it 'rejects a commentable type whose class does not include Commentable' do
      page = create(:page)
      config = described_class.new(commentable_type: 'BetterTogether::Page', commentable_id: page.id)

      expect(config).not_to be_valid
      expect(config.errors[:commentable_type]).to be_present
    end
  end

  describe '.permitted_attributes' do
    it 'permits permission and visibility only by default' do
      expect(described_class.permitted_attributes).to match_array(%i[permission visibility])
    end

    it 'adds id and _destroy when requested' do
      expect(described_class.permitted_attributes(id: true, destroy: true))
        .to match_array(%i[permission visibility id _destroy])
    end
  end
end

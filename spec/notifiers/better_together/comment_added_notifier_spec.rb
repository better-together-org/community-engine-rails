# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::CommentAddedNotifier do
  subject(:notifier) do
    described_class.new(record: comment, params: { comment: comment })
  end

  let(:commenter) { create(:better_together_person, name: 'Ada Commenter') }
  let(:post_creator) { create(:better_together_person) }
  let(:post) { create(:post, creator: post_creator, author: post_creator) }
  let(:comment) { create(:comment, creator: commenter, commentable: post, content: 'A great point!') }
  let(:notification) { instance_double(Noticed::Notification, recipient: post_creator) }

  describe '#title' do
    it "includes the commenter's name" do
      expect(notifier.title).to include('Ada Commenter')
    end
  end

  describe '#body' do
    it 'includes the comment content' do
      expect(notifier.body).to include('A great point!')
    end
  end

  describe '#build_message' do
    it 'returns a hash with title, body, and url' do
      message = notifier.build_message(notification)
      expect(message).to include(:title, :body, :url)
    end

    it 'includes a URL to the commented-on post' do
      message = notifier.build_message(notification)
      expect(message[:url]).to include(post.to_param)
    end
  end

  describe '#email_params' do
    it 'uses notification.recipient instead of a bare recipient reference' do
      params = notifier.email_params(notification)
      expect(params[:recipient]).to eq(post_creator)
    end

    it 'includes the comment' do
      params = notifier.email_params(notification)
      expect(params[:comment]).to eq(comment)
    end
  end

  describe 'delivery integration' do
    it 'creates a Noticed::Notification for the recipient on deliver_later' do
      expect do
        described_class.with(record: comment, comment: comment).deliver_later(post_creator)
      end.to change(Noticed::Notification, :count).by(1)
    end
  end
end

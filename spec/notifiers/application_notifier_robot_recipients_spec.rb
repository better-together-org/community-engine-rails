# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ApplicationNotifier, '#deliver' do # rubocop:disable RSpec/SpecFilePathFormat
  let(:author) { create(:better_together_person) }
  let(:robot) { create(:better_together_robot) }
  let(:person) { create(:better_together_person) }
  let(:post) { create(:post, creator: author, author:) }
  let(:comment) { create(:comment, creator: author, commentable: post) }
  let(:notifier) { BetterTogether::CommentAddedNotifier.with(record: comment, comment:) }

  %i[deliver deliver_later].each do |method|
    context "with ##{method}" do
      it 'notifies people and skips robots', :aggregate_failures do
        event = nil
        expect { event = notifier.public_send(method, [person, robot]) }
          .to have_enqueued_job(Noticed::EventJob).once

        expect(event.notifications.map(&:recipient)).to eq([person])
      end

      it 'saves and queues nothing when every recipient is a robot', :aggregate_failures do
        notifier # build the comment first: its own creation may notify the author
        saved = -> { Noticed::Event.count + Noticed::Notification.count }

        expect { notifier.public_send(method, robot) }.not_to(change(saved, :call))
        expect { notifier.public_send(method, robot) }.not_to have_enqueued_job(Noticed::EventJob)
      end
    end
  end
end

# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::FederationHub::PersonalContentSummaryService do
  describe '.call' do
    it 'returns a nil-safe default summary when person is nil' do
      result = described_class.call(person: nil)

      expect(result).to eq(federate_content: nil, counts_by_visibility: {}, recent_items: [])
    end

    it "reports the person's federate_content preference" do
      person = create(:better_together_person, federate_content: true)

      expect(described_class.call(person:)[:federate_content]).to be true
    end

    it 'counts content by federation_visibility across post/page/event' do
      person = create(:better_together_person)
      create(:better_together_post, creator: person, federation_visibility: 'federate')
      create(:better_together_page, creator: person, federation_visibility: 'federate')
      create(:event, creator: person, federation_visibility: 'no_federate')
      create(:better_together_post, creator: person, federation_visibility: 'platform_default')

      counts = described_class.call(person:)[:counts_by_visibility]

      expect(counts['federate']).to eq(2)
      expect(counts['no_federate']).to eq(1)
      expect(counts['platform_default']).to eq(1)
    end

    it "does not count another person's content" do
      person = create(:better_together_person)
      other = create(:better_together_person)
      create(:better_together_post, creator: other, federation_visibility: 'federate')

      counts = described_class.call(person:)[:counts_by_visibility]

      expect(counts).to be_empty
    end

    it 'returns the most recently updated items first, capped at 5' do
      person = create(:better_together_person)
      # after_commit :add_creator_as_author re-touches updated_at on create, so force the
      # intended ordering afterward with update_column (bypasses callbacks/validations).
      posts = Array.new(6) { create(:better_together_post, creator: person) }
      posts.each_with_index { |post, i| post.update_column(:updated_at, i.days.ago) }

      recent_items = described_class.call(person:)[:recent_items]

      expect(recent_items.length).to eq(5)
      expect(recent_items.first).to eq(posts.first)
    end
  end
end

# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Post, type: :model do # rubocop:todo Metrics/BlockLength
  let(:post) { build(:better_together_post) }
  let(:post_draft) { build(:better_together_post, :draft) }
  let(:post_published) { build(:better_together_post, :published) }
  let(:post_scheduled) { build(:better_together_post, :scheduled) }
  subject { post }

  describe 'has a valid factory' do
    it { is_expected.to be_valid }
  end

  describe 'ActiveRecord associations' do
    it { is_expected.to have_many(:authorships) }
    it { is_expected.to have_many(:authors).through(:authorships) }
  end

  describe 'ActiveModel validations' do
  end

  describe 'callbacks' do
  end

  it_behaves_like 'a translatable record'
  it_behaves_like 'a friendly slugged record'
  it_behaves_like 'an authorable model'
  it_behaves_like 'has_bt_id'

  describe '#post_privacy' do
    it {
      is_expected.to define_enum_for(:post_privacy)
        .backed_by_column_of_type(:string)
        .with_values(described_class::PRIVACY_LEVELS)
        .with_prefix(:post_privacy)
    }
  end

  describe '.draft' do
    it { expect(described_class).to respond_to(:draft) }
    it { expect(described_class.draft.new.published_at).to be_nil }
  end

  describe '.published' do
    it { expect(described_class).to respond_to(:published) }
    it { expect(described_class.published).to be_empty }
  end

  describe '.scheduled' do
    it { expect(described_class).to respond_to(:scheduled) }
    it { expect(described_class.scheduled).to be_empty }
  end

  describe '#title' do
    it { is_expected.to respond_to(:title) }
  end

  describe '#content' do
    it { is_expected.to respond_to(:content) }
  end

  describe '#content_html' do
    it { is_expected.to respond_to(:content_html) }
  end

  describe '#published_at' do
    it { is_expected.to respond_to(:published_at) }
  end

  describe '#draft?' do
    it { is_expected.to respond_to(:draft?) }
    it 'returns true if the published_at date is nil' do
      expect(post_draft.draft?).to be_truthy
    end
  end

  describe '#published?' do
    it { is_expected.to respond_to(:published?) }
    it 'returns true if the published_at date is in the past' do
      expect(post_published.published?).to be_truthy
    end
  end

  describe '#scheduled?' do
    it { is_expected.to respond_to(:scheduled?) }
    it 'returns true if the published_at date in the future' do
      expect(post_scheduled.scheduled?).to be_truthy
    end
  end
end

# frozen_string_literal: true

require 'rails_helper'

module BetterTogether
  # rubocop:disable Metrics/BlockLength
  RSpec.describe NotificationsPolicy do
    subject(:policy) { described_class.new(user, :notifications) }

    context 'when user is logged in' do
      let(:user) { build(:user) }

      it 'permits index' do
        expect(policy.index?).to be true
      end

      it 'permits mark_as_read' do
        expect(policy.mark_as_read?).to be true
      end

      it 'permits mark_notification_as_read' do
        expect(policy.mark_notification_as_read?).to be true
      end

      it 'permits mark_record_notification_as_read' do
        expect(policy.mark_record_notification_as_read?).to be true
      end
    end

    context 'when user is nil' do
      let(:user) { nil }

      it 'denies index' do
        expect(policy.index?).to be false
      end

      it 'denies mark_as_read' do
        expect(policy.mark_as_read?).to be false
      end

      it 'denies mark_notification_as_read' do
        expect(policy.mark_notification_as_read?).to be false
      end

      it 'denies mark_record_notification_as_read' do
        expect(policy.mark_record_notification_as_read?).to be false
      end
    end
  end
  # rubocop:enable Metrics/BlockLength
end

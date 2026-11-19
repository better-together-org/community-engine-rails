# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::ContentSecurity::AttachmentBackfill, type: :service do
  let(:config) { BetterTogether::ContentSecurity::Configuration }

  let!(:upload) do
    allow(config).to receive(:enabled?).and_return(false)
    record = build(:better_together_upload)
    record.file.attach(io: StringIO.new('hello'), filename: 'hello.txt', content_type: 'text/plain')
    record.save!
    record
  end

  context 'when scanning is disabled' do
    before { allow(config).to receive(:enabled?).and_return(false) }

    it 'does nothing' do
      expect(described_class.call.enrolled).to eq(0)
    end
  end

  context 'when the uploads surface is enabled' do
    before do
      allow(config).to receive_messages(enabled?: true, enabled_for_surface?: true)
    end

    it 'counts but does not enroll on a dry run' do
      expect { described_class.call(dry_run: true) }
        .not_to change(BetterTogether::ContentSecurity::Item, :count)
      expect(described_class.call(dry_run: true).enrolled).to be >= 1
    end

    it 'enrolls existing uploads and schedules a scan' do
      expect { described_class.call }
        .to change(BetterTogether::ContentSecurity::Item, :count).by_at_least(1)
      expect(BetterTogether::ContentSecurity::Item.for_attachment(upload, :file)).to exist
    end

    it 'is idempotent' do
      described_class.call
      expect { described_class.call }.not_to change(BetterTogether::ContentSecurity::Item, :count)
    end
  end

  context 'when the uploads surface is disabled' do
    before do
      allow(config).to receive_messages(enabled?: true)
      allow(config).to receive(:enabled_for_surface?).and_return(false)
    end

    it 'skips the surface' do
      summary = described_class.call
      expect(summary.enrolled).to eq(0)
      expect(summary.skipped_surface_disabled).to be >= 1
    end
  end
end

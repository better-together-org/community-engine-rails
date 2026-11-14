# frozen_string_literal: true

require 'rails_helper'

# rubocop:disable-next Layout/LineLength
RSpec.describe 'Seed packet blob transport' do # rubocop:disable RSpec/DescribeClass
  let(:dir) { Dir.mktmpdir('seed-blobs') }
  let(:pdf) { "%PDF-1.4 packet blob #{SecureRandom.hex(4)}" }
  let!(:sha) { write_blob(dir, pdf) }

  before do
    File.write(File.join(dir, 'packet.yml'), "better_together: {}\n")
    write_manifest(dir)
  end

  after do
    FileUtils.remove_entry(dir)
    BetterTogether::Seeds::PacketSources.reset!
  end

  describe BetterTogether::Seeds::Manifest do
    it 'verifies an intact packet' do
      expect(described_class.load(dir).verify(dir)).to be_valid
    end

    it 'rejects a blob changed after the manifest was written' do
      File.binwrite(File.join(dir, 'blobs', sha), pdf.sub('packet', 'tamper'))

      messages = described_class.load(dir).verify(dir).errors.map(&:message)

      expect(messages).to include(/size|sha256 does not match/)
    end

    it 'rejects same-size tampering by hash' do
      File.binwrite(File.join(dir, 'blobs', sha), pdf.tr('a', 'b'))

      expect(described_class.load(dir).verify(dir).errors.map(&:message)).to include(/sha256 does not match/)
    end

    it 'reports missing and unlisted files' do
      File.delete(File.join(dir, 'blobs', sha))
      File.write(File.join(dir, 'records.yml'), 'x')

      messages = described_class.load(dir).verify(dir).errors.map(&:message)

      expect(messages).to include(/missing/, /not in the manifest/)
    end

    it 'enforces the per-blob size policy' do
      allow(BetterTogether::Seeds::BlobPolicy).to receive(:max_blob_bytes).and_return(5)

      expect(described_class.load(dir).verify(dir).errors.map(&:message)).to include(/blob limit/)
    end

    it 'enforces the packet-wide size policy' do
      allow(BetterTogether::Seeds::BlobPolicy).to receive(:max_packet_bytes).and_return(5)

      expect(described_class.load(dir).verify(dir).errors.map(&:message)).to include(/byte limit/)
    end

    it 'fails clearly without a manifest' do
      File.delete(File.join(dir, 'MANIFEST.json'))

      expect { described_class.load(dir) }.to raise_error(ArgumentError, /MANIFEST.json is missing/)
    end
  end

  describe BetterTogether::Seeds::PacketSources do
    it 'allows config/seeds and registered roots' do
      described_class.register_root(File.dirname(dir))

      expect(described_class.resolve!(dir).to_s).to eq(File.realpath(dir))
      expect(described_class.resolve!(BetterTogether::Engine.root.join('config/seeds'))).to be_present
    end

    it 'refuses paths outside the allowed roots' do
      expect { described_class.resolve!(dir) }.to raise_error(described_class::Forbidden, /outside the allowed roots/)
    end

    it 'refuses traversal and symlinks that escape a root' do
      described_class.register_root(dir)
      File.symlink('/etc', File.join(dir, 'escape'))

      expect { described_class.resolve!("#{dir}/../x") }.to raise_error(described_class::Forbidden, /\.\./)
      expect { described_class.resolve!(File.join(dir, 'escape')) }.to raise_error(described_class::Forbidden)
    end

    it 'reads extra roots from the environment' do
      stub_const('ENV', ENV.to_hash.merge('BETTER_TOGETHER_SEED_PACKET_ROOTS' => dir))

      expect(described_class.resolve!(dir)).to be_present
    end
  end

  describe BetterTogether::Seeds::PacketArchive do
    let(:archive) { File.join(Dir.mktmpdir('seed-archive'), 'packet.tar.gz') }
    let(:dest) { File.join(Dir.mktmpdir('seed-dest'), 'out') }

    it 'extracts a conforming packet' do
      tar_gz(archive, [['packet.yml', 'a: 1'], ["blobs/#{sha}", pdf]])

      described_class.extract(archive, dest)

      expect(File.binread(File.join(dest, 'blobs', sha))).to eq(pdf)
    end

    it 'rejects traversal, absolute paths and unknown layout' do
      ['../evil.yml', '/etc/passwd', 'other/file.txt'].each do |name|
        tar_gz(archive, [[name, 'x']])

        expect { described_class.extract(archive, Dir.mktmpdir('seed-d')) }.to raise_error(described_class::Rejected)
      end
    end

    it 'rejects links' do
      tar_gz(archive, [['packet.yml', '/etc/passwd', :symlink]])

      expect { described_class.extract(archive, Dir.mktmpdir('seed-d')) }.to raise_error(described_class::Rejected, /regular files/)
    end

    it 'enforces the archive size cap while streaming' do
      tar_gz(archive, [['packet.yml', 'x' * 100]])

      expect { described_class.extract(archive, Dir.mktmpdir('seed-d'), max_bytes: 10) }.to raise_error(described_class::Rejected, /size/)
    end

    it 'refuses a non-empty destination' do
      tar_gz(archive, [['packet.yml', 'a']])

      expect { described_class.extract(archive, dir) }.to raise_error(described_class::Rejected, /empty/)
    end
  end

  describe BetterTogether::Seeds::BlobAttacher do
    let(:platform) { create(:better_together_platform) }
    let(:upload) { create(:better_together_upload, platform:, privacy: 'private') }
    let(:entry) do
      Struct.new(:files).new([{ 'attachment' => 'file', 'blob' => "blobs/#{sha}", 'filename' => 'a.pdf',
                                'content_type' => 'application/pdf', 'checksum' => sha }])
    end
    let(:attacher) { described_class.new(root: dir, manifest: BetterTogether::Seeds::Manifest.load(dir)) }

    it 'attaches the blob with the declared filename and content type' do
      attacher.call(record: upload, entry:)

      expect(upload.reload.file.download).to eq(pdf)
      expect(upload.file.filename.to_s).to eq('a.pdf')
    end

    it 'is a no-op when identical bytes are already attached' do
      attacher.call(record: upload, entry:)

      expect { attacher.call(record: upload.reload, entry:) }.not_to change(ActiveStorage::Blob, :count)
    end

    it 'rejects a blob altered after verification' do
      File.binwrite(File.join(dir, 'blobs', sha), "#{pdf}!")

      expect { attacher.call(record: upload, entry:) }.to raise_error(described_class::Rejected, /changed after verification/)
    end

    it 'rejects a blob that is not in the manifest' do
      bad = Struct.new(:files).new([entry.files.first.merge('checksum' => 'f' * 64)])

      expect { attacher.call(record: upload, entry: bad) }.to raise_error(described_class::Rejected, /not in the manifest/)
    end

    it 'rejects a content type that disagrees with the manifest' do
      bad = Struct.new(:files).new([entry.files.first.merge('content_type' => 'image/png')])

      expect { attacher.call(record: upload, entry: bad) }.to raise_error(described_class::Rejected, /content type/)
    end

    it 'enrolls the attachment for content-security scanning when scanning is enabled' do
      allow(BetterTogether::ContentSecurity::Configuration).to receive(:enabled?).and_return(true)
      allow(BetterTogether::ContentSecurity::AttachmentEnrollment).to receive(:sync_attachment!)

      attacher.call(record: upload, entry:)
      upload.run_callbacks(:commit)

      expect(BetterTogether::ContentSecurity::AttachmentEnrollment).to have_received(:sync_attachment!).with(hash_including(attachment_name: 'file')).at_least(:once)
    end
  end
end

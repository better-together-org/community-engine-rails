# frozen_string_literal: true

require 'rails_helper'

# Instance methods added via `include` survive rspec-rebound's example wrapper,
# unlike a bare `def` inside a nested `describe`.
module ActiveStorageSecuritySpecHelpers
  def block_on(page, block_privacy)
    block = create(:content_markdown).tap { |b| b.update_columns(privacy: block_privacy) }
    create(:page_content_block, page: page, block: block)
    block
  end
end

module BetterTogether
  # rubocop:todo RSpec/SpecFilePathFormat
  RSpec.describe ActiveStorageSecurity do
    # rubocop:enable RSpec/SpecFilePathFormat

    # Build a minimal anonymous controller that includes the concern so we can
    # unit-test the private helpers without standing up full AS routing.
    let(:controller_class) do
      Class.new(ActionController::Base) do
        include BetterTogether::ActiveStorageSecurity

        # Stubs for Devise helpers injected at runtime
        attr_writer :current_user, :user_signed_in

        def user_signed_in?
          @user_signed_in
        end
      end
    end

    let(:controller) { controller_class.new }

    before do
      controller.instance_variable_set(:@_response, ActionDispatch::TestResponse.create)
    end

    describe '#verify_content_signature' do
      let(:blob) do
        instance_double(ActiveStorage::Blob, id: 'blob-id', content_type: declared_type, filename: filename)
      end

      before do
        controller.instance_variable_set(:@blob, blob)
        allow(blob).to receive(:download_chunk).with(0...described_class::CONTENT_SIGNATURE_SNIFF_BYTES)
                                               .and_return(bytes)
      end

      context 'when the blob is not present' do
        let(:declared_type) { 'image/png' }
        let(:filename) { ActiveStorage::Filename.new('avatar.png') }
        let(:bytes) { "\x89PNG\r\n\x1a\n".b }

        it 'does not render' do
          controller.instance_variable_set(:@blob, nil)
          expect(controller).not_to receive(:head)
          controller.send(:verify_content_signature)
        end
      end

      context 'when the real content matches the declared type' do
        let(:declared_type) { 'image/png' }
        let(:filename) { ActiveStorage::Filename.new('avatar.png') }
        let(:bytes) { "\x89PNG\r\n\x1a\n".b }

        it 'does not render' do
          expect(controller).not_to receive(:head)
          controller.send(:verify_content_signature)
        end
      end

      context 'when the real content does not match the declared type' do
        let(:declared_type) { 'image/png' }
        let(:filename) { ActiveStorage::Filename.new('avatar.png') }
        # Filename still claims .png/image-png, but the real bytes have a strong,
        # unambiguous, unrelated magic signature -- exactly the attack pattern this
        # check exists to catch (declared image/png, actual bytes something else
        # entirely). A ZIP header is used here as a stand-in for "some other definite,
        # unrelated format" rather than the real MATLAB signature from the observed
        # attack, since the exact test fixture format doesn't matter -- only that
        # magic-byte detection returns something concrete and different from the
        # declared type.
        let(:bytes) { "PK\x03\x04\x14\x00\x00\x00\x00\x00".b }

        it 'renders 422 and does not proceed to authorization' do
          expect(controller).to receive(:head).with(:unprocessable_entity)
          controller.send(:verify_content_signature)
        end
      end

      context 'when the real content has no recognizable magic signature' do
        let(:declared_type) { 'image/png' }
        let(:filename) { ActiveStorage::Filename.new('avatar.png') }
        let(:bytes) { 'this is plain text with no strong magic-byte signature' }

        it 'fails open and does not render' do
          expect(controller).not_to receive(:head)
          controller.send(:verify_content_signature)
        end
      end

      context 'when sniffing the content raises' do
        let(:declared_type) { 'image/png' }
        let(:filename) { ActiveStorage::Filename.new('avatar.png') }
        let(:bytes) { "\x89PNG\r\n\x1a\n".b }

        it 'fails open and does not render' do
          allow(blob).to receive(:download_chunk).and_raise(StandardError, 'storage unavailable')
          expect(controller).not_to receive(:head)
          controller.send(:verify_content_signature)
        end
      end
    end

    describe '#publicly_accessible?' do
      context 'when the record is nil' do
        it 'returns false' do
          expect(controller.send(:publicly_accessible?, nil)).to be false
        end
      end

      context 'when the record does not respond to privacy_public?' do
        it 'returns false' do
          expect(controller.send(:publicly_accessible?, Object.new)).to be false
        end
      end

      context 'when the record is privacy_public?' do
        let(:record) { instance_double(BetterTogether::Upload, privacy_public?: true) }

        it 'returns true' do
          expect(controller.send(:publicly_accessible?, record)).to be true
        end
      end

      context 'when the record is not privacy_public?' do
        let(:record) { instance_double(BetterTogether::Upload, privacy_public?: false) }

        it 'returns false' do
          expect(controller.send(:publicly_accessible?, record)).to be false
        end
      end

      context 'when the record is a Content::Block' do
        include ActiveStorageSecuritySpecHelpers

        let(:published_public_page) { create(:better_together_page, privacy: 'public', published_at: 1.day.ago) }
        let(:unpublished_page) { create(:better_together_page, privacy: 'public', published_at: nil) }

        it 'delegates to BlockPolicy#show? (anonymous) instead of the bare privacy check' do
          public_block = block_on(published_public_page, 'public')
          expect(controller.send(:publicly_accessible?, public_block)).to be true
        end

        it 'is not publicly accessible when the block is public but its page is unpublished' do
          orphaned_public_block = block_on(unpublished_page, 'public')
          expect(orphaned_public_block.privacy_public?).to be true
          expect(controller.send(:publicly_accessible?, orphaned_public_block)).to be false
        end

        it 'is not publicly accessible for a community block on a public page' do
          community_block = block_on(published_public_page, 'community')
          expect(controller.send(:publicly_accessible?, community_block)).to be false
        end
      end

      context 'when the record is a Sitemap' do
        # belongs_to :platform enforces a real Platform instance, so a
        # build_stubbed record (unpersisted but type-correct) is stubbed rather
        # than doubled.
        let(:platform) { build_stubbed(:better_together_platform) }
        let(:sitemap) { BetterTogether::Sitemap.new(platform: platform, locale: 'en') }

        context 'when the platform is locally-hosted and public' do
          before do
            allow(platform).to receive_messages(local_hosted?: true, privacy_public?: true)
          end

          it 'returns true' do
            expect(controller.send(:publicly_accessible?, sitemap)).to be true
          end
        end

        context 'when the platform is locally-hosted but not public' do
          before do
            allow(platform).to receive_messages(local_hosted?: true, privacy_public?: false)
          end

          it 'returns false' do
            expect(controller.send(:publicly_accessible?, sitemap)).to be false
          end
        end

        context 'when the platform is not locally-hosted' do
          before do
            allow(platform).to receive_messages(local_hosted?: false, privacy_public?: true)
          end

          it 'returns false' do
            expect(controller.send(:publicly_accessible?, sitemap)).to be false
          end
        end
      end

      context 'when the record is a Settlement, Category, or other Privacy-including record' do
        it 'returns true for a public settlement' do
          settlement = instance_double(BetterTogether::Geography::Settlement, privacy_public?: true)
          expect(controller.send(:publicly_accessible?, settlement)).to be true
        end

        it 'returns false for a private category' do
          category = instance_double(BetterTogether::Category, privacy_public?: false)
          expect(controller.send(:publicly_accessible?, category)).to be false
        end
      end
    end

    describe '#resolve_authorizable_record' do
      include ActiveStorageSecuritySpecHelpers

      context 'when the record is not an ActionText::RichText' do
        it 'returns the record unchanged' do
          record = instance_double(BetterTogether::Upload)
          expect(controller.send(:resolve_authorizable_record, record)).to eq(record)
        end

        it 'passes nil through unchanged' do
          expect(controller.send(:resolve_authorizable_record, nil)).to be_nil
        end
      end

      context 'when the record is an ActionText::RichText embedded in a plain Privacy-including field' do
        it "resolves to the rich text's owning record (e.g. Page#content)" do
          page = create(:better_together_page, privacy: 'public', published_at: 1.day.ago)
          rich_text = ActionText::RichText.new(record: page, name: 'content', body: '<img src="x">')

          resolved = controller.send(:resolve_authorizable_record, rich_text)

          expect(resolved).to eq(page)
          expect(controller.send(:publicly_accessible?, resolved)).to be true
        end
      end

      context 'when the record is an ActionText::RichText embedded in a Content::Block field' do
        let(:published_public_page) { create(:better_together_page, privacy: 'public', published_at: 1.day.ago) }

        it 'resolves to the block so BlockPolicy#show? governs it, not a bare privacy check' do
          public_block = block_on(published_public_page, 'public')
          rich_text = ActionText::RichText.new(record: public_block, name: 'content', body: '<img src="x">')

          resolved = controller.send(:resolve_authorizable_record, rich_text)

          expect(resolved).to eq(public_block)
          expect(controller.send(:publicly_accessible?, resolved)).to be true
        end
      end

      context 'when the ActionText::RichText is orphaned (its owning record was deleted)' do
        it 'resolves to nil rather than raising' do
          rich_text = ActionText::RichText.new(record: nil, name: 'content', body: '<img src="x">')

          resolved = controller.send(:resolve_authorizable_record, rich_text)

          expect(resolved).to be_nil
          expect(controller.send(:publicly_accessible?, resolved)).to be false
        end
      end

      context 'when resolving the record raises' do
        it 'returns nil rather than propagating the error' do
          record = instance_double(ActionText::RichText)
          allow(record).to receive(:is_a?).with(ActionText::RichText).and_return(true)
          allow(record).to receive(:record).and_raise(StandardError, 'db unavailable')

          expect(controller.send(:resolve_authorizable_record, record)).to be_nil
        end
      end
    end

    describe '#enforce_download_policy!' do
      let(:user) { build_stubbed(:better_together_person) }
      let(:record) { instance_double(BetterTogether::Upload) }

      before { controller.current_user = user }

      context 'when the policy has no download? method' do
        let(:policy) { instance_double(BetterTogether::ApplicationPolicy) }

        before do
          allow(Pundit).to receive(:policy).with(user, record).and_return(policy)
          allow(policy).to receive(:respond_to?).with(:download?).and_return(false)
        end

        it 'does not render' do
          expect(controller).not_to receive(:head)
          controller.send(:enforce_download_policy!, record)
        end
      end

      context 'when download? returns true' do
        let(:policy) { instance_double(BetterTogether::UploadPolicy, download?: true) }

        before do
          allow(Pundit).to receive(:policy).with(user, record).and_return(policy)
          allow(policy).to receive(:respond_to?).with(:download?).and_return(true)
        end

        it 'does not render' do
          expect(controller).not_to receive(:head)
          controller.send(:enforce_download_policy!, record)
        end
      end

      context 'when download? returns false' do
        let(:policy) { instance_double(BetterTogether::UploadPolicy, download?: false) }

        before do
          allow(Pundit).to receive(:policy).with(user, record).and_return(policy)
          allow(policy).to receive(:respond_to?).with(:download?).and_return(true)
        end

        it 'renders 403' do
          expect(controller).to receive(:head).with(:forbidden)
          controller.send(:enforce_download_policy!, record)
        end
      end

      context 'when Pundit raises NotAuthorizedError' do
        before do
          allow(Pundit).to receive(:policy).with(user, record).and_raise(Pundit::NotAuthorizedError)
        end

        it 'renders 403' do
          expect(controller).to receive(:head).with(:forbidden)
          controller.send(:enforce_download_policy!, record)
        end
      end
    end

    describe '#apply_media_cache_headers' do
      let(:blob) { instance_double(ActiveStorage::Blob) }

      before do
        controller.instance_variable_set(:@blob, blob)
      end

      it 'marks public blobs as public cacheable' do
        allow(BetterTogether::MediaCachePolicy).to receive(:for_blob)
          .with(blob)
          .and_return(instance_double(BetterTogether::MediaCachePolicy,
                                      cache_scope: 'public',
                                      public?: true))

        controller.send(:apply_media_cache_headers)

        expect(controller.response.headers['X-BTS-Cache-Scope']).to eq('public')
      end

      it 'marks non-public blobs as private and no-store' do
        allow(BetterTogether::MediaCachePolicy).to receive(:for_blob)
          .with(blob)
          .and_return(instance_double(BetterTogether::MediaCachePolicy,
                                      cache_scope: 'private',
                                      public?: false))

        controller.send(:apply_media_cache_headers)

        expect(controller.response.headers['X-BTS-Cache-Scope']).to eq('private')
        expect(controller.response.headers['Cache-Control']).to eq('private, no-store')
      end
    end

    describe 'initializer wires up AS proxy and redirect controllers' do
      it 'includes the concern in ActiveStorage::Blobs::ProxyController' do
        expect(ActiveStorage::Blobs::ProxyController.ancestors).to include(described_class)
      end

      it 'includes the concern in ActiveStorage::Blobs::RedirectController' do
        expect(ActiveStorage::Blobs::RedirectController.ancestors).to include(described_class)
      end

      it 'includes the concern in ActiveStorage::Representations::ProxyController' do
        expect(ActiveStorage::Representations::ProxyController.ancestors).to include(described_class)
      end

      it 'includes the concern in ActiveStorage::Representations::RedirectController' do
        expect(ActiveStorage::Representations::RedirectController.ancestors).to include(described_class)
      end
    end
  end
end

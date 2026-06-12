# frozen_string_literal: true

require 'rails_helper'

# Specs for platform-admin storage configuration management.
# Nested under /host/platforms/:platform_id/storage_configurations.
# All actions require manage_platform permission (enforced via route constraint + Pundit).
RSpec.describe 'BetterTogether::StorageConfigurationsController', :as_platform_manager do
  let(:locale) { I18n.default_locale }
  let(:regular_user) { create(:better_together_user, :confirmed) }
  let(:platform) do
    create(:better_together_platform,
           identifier: "platform-#{SecureRandom.hex(6)}",
           host_url: "http://platform-#{SecureRandom.hex(6)}.test")
  end

  def index_path
    platform_storage_configurations_path(platform, locale:)
  end

  def new_path
    new_platform_storage_configuration_path(platform, locale:)
  end

  def edit_path(config)
    edit_platform_storage_configuration_path(platform, config, locale:)
  end

  def activate_path(config)
    activate_platform_storage_configuration_path(platform, config, locale:)
  end

  def destroy_path(config)
    platform_storage_configuration_path(platform, config, locale:)
  end

  # ---------------------------------------------------------------------------
  # GET index
  # ---------------------------------------------------------------------------
  describe 'GET /host/platforms/:platform_id/storage_configurations' do
    let!(:config) { create(:better_together_storage_configuration, platform:, name: 'My Local Store') }

    it 'returns 200' do
      get index_path
      expect(response).to have_http_status(:ok)
    end

    it 'displays the configuration name' do
      get index_path
      expect_html_content('My Local Store')
    end

    it 'does not show configurations from other platforms' do
      other_platform = create(:better_together_platform,
                              identifier: "other-#{SecureRandom.hex(6)}",
                              host_url: "http://other-#{SecureRandom.hex(6)}.test")
      other_config = create(:better_together_storage_configuration, platform: other_platform, name: 'Other Store')
      get index_path
      expect(response.body).not_to include(other_config.name)
    end

    it 'redirects signed-in non-managers away from index' do
      sign_in regular_user

      get index_path

      expect(response).to have_http_status(:not_found)
    end
  end

  # ---------------------------------------------------------------------------
  # GET new
  # ---------------------------------------------------------------------------
  describe 'GET /host/platforms/:platform_id/storage_configurations/new' do
    it 'renders the new form' do
      get new_path
      expect(response).to have_http_status(:ok)
    end

    it 'includes the name field' do
      get new_path
      expect(response.body).to include('storage_configuration[name]')
    end

    it 'includes the service_type field' do
      get new_path
      expect(response.body).to include('storage_configuration[service_type]')
    end

    it 'redirects signed-in non-managers away from new' do
      sign_in regular_user

      get new_path

      expect(response).to have_http_status(:not_found)
    end
  end

  # ---------------------------------------------------------------------------
  # GET edit
  # ---------------------------------------------------------------------------
  describe 'GET /host/platforms/:platform_id/storage_configurations/:id/edit' do
    let!(:config) { create(:better_together_storage_configuration, platform:, name: 'Edit Me') }

    it 'renders the edit form' do
      get edit_path(config)
      expect(response).to have_http_status(:ok)
    end

    it 'displays the configuration name in the form' do
      get edit_path(config)
      expect_html_content('Edit Me')
    end
  end

  # ---------------------------------------------------------------------------
  # POST create — local storage
  # ---------------------------------------------------------------------------
  describe 'POST /host/platforms/:platform_id/storage_configurations (local)' do
    let(:valid_local_params) do
      { storage_configuration: { name: 'Local Disk', service_type: 'local' } }
    end

    it 'creates a local storage configuration and redirects' do
      expect do
        post index_path, params: valid_local_params
      end.to change(BetterTogether::StorageConfiguration, :count).by(1)

      expect(response).to have_http_status(:see_other)
      follow_redirect!
      expect(response).to have_http_status(:ok)
    end

    it 'rejects creation with missing name' do
      expect do
        post index_path, params: { storage_configuration: { service_type: 'local' } }
      end.not_to change(BetterTogether::StorageConfiguration, :count)

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  # ---------------------------------------------------------------------------
  # POST create — S3 storage
  # ---------------------------------------------------------------------------
  describe 'POST /host/platforms/:platform_id/storage_configurations (amazon S3)' do
    let(:valid_s3_params) do
      {
        storage_configuration: {
          name: 'Amazon S3',
          service_type: 'amazon',
          bucket: 'my-bucket',
          region: 'us-east-1',
          access_key_id: 'AKIAIOSFODNN7EXAMPLE',
          secret_access_key: 'wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY'
        }
      }
    end

    it 'creates an S3 storage configuration and redirects' do
      expect do
        post index_path, params: valid_s3_params
      end.to change(BetterTogether::StorageConfiguration, :count).by(1)

      expect(response).to have_http_status(:see_other)
    end

    it 'rejects S3 creation when bucket is missing' do
      params = valid_s3_params.deep_dup
      params[:storage_configuration].delete(:bucket)

      expect do
        post index_path, params:
      end.not_to change(BetterTogether::StorageConfiguration, :count)

      expect(response).to have_http_status(:unprocessable_content)
    end

    it 'rejects S3 creation when credentials are missing' do
      params = valid_s3_params.deep_dup
      params[:storage_configuration].delete(:access_key_id)
      params[:storage_configuration].delete(:secret_access_key)

      expect do
        post index_path, params:
      end.not_to change(BetterTogether::StorageConfiguration, :count)

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  # ---------------------------------------------------------------------------
  # PATCH update
  # ---------------------------------------------------------------------------
  describe 'PATCH /host/platforms/:platform_id/storage_configurations/:id' do
    let!(:config) { create(:better_together_storage_configuration, platform:, name: 'Original Name') }

    it 'updates the name and redirects' do
      patch platform_storage_configuration_path(platform, config, locale:),
            params: { storage_configuration: { name: 'Updated Name', service_type: 'local' } }

      expect(response).to have_http_status(:see_other)
      expect(config.reload.name).to eq('Updated Name')
    end

    it 'preserves existing S3 credentials when blank values are submitted' do
      s3_config = create(:better_together_storage_configuration, :amazon, platform:)

      patch platform_storage_configuration_path(platform, s3_config, locale:),
            params: {
              storage_configuration: {
                name: 'Updated S3',
                service_type: 'amazon',
                bucket: s3_config.bucket,
                region: s3_config.region,
                access_key_id: '',
                secret_access_key: ''
              }
            }

      expect(response).to have_http_status(:see_other)
      # Credentials should be unchanged (blank values stripped by update_params)
      expect(s3_config.reload.access_key_id).to eq('AKIAIOSFODNN7EXAMPLE')
      expect(s3_config.reload.secret_access_key).to eq('wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY')
    end

    it 'rejects update with invalid params' do
      patch platform_storage_configuration_path(platform, config, locale:),
            params: { storage_configuration: { name: '', service_type: 'local' } }

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  # ---------------------------------------------------------------------------
  # DELETE destroy
  # ---------------------------------------------------------------------------
  describe 'DELETE /host/platforms/:platform_id/storage_configurations/:id' do
    let!(:config) { create(:better_together_storage_configuration, platform:) }

    it 'destroys a non-active configuration and redirects' do
      expect do
        delete destroy_path(config)
      end.to change(BetterTogether::StorageConfiguration, :count).by(-1)

      expect(response).to have_http_status(:see_other)
    end

    it 'prevents deletion of the active configuration' do
      platform.update!(storage_configuration_id: config.id)

      expect do
        delete destroy_path(config)
      end.not_to change(BetterTogether::StorageConfiguration, :count)

      expect(response).to have_http_status(:see_other)
      follow_redirect!
      expect(response.body).to include(
        I18n.t('better_together.storage_configurations.cannot_destroy_active')
      )
    end
  end

  # ---------------------------------------------------------------------------
  # PUT activate
  # ---------------------------------------------------------------------------
  describe 'PUT /host/platforms/:platform_id/storage_configurations/:id/activate' do
    let!(:config) { create(:better_together_storage_configuration, platform:, name: 'Primary Store') }

    before do
      # Force a fresh HTTP login for every example in this describe block.
      # The automatic auth helper caches the "already authenticated" state by
      # parent-group description (Thread.current[:__bt_authenticated_description]),
      # so consecutive examples with identical parent descriptions can have their
      # login silently skipped.  An explicit login here guarantees a valid session
      # regardless of what ran before.
      login('manager@example.test', 'SecureTest123!@#')
      # Stub the private rebind helper so activate doesn't need a live AS backend.
      allow_any_instance_of(BetterTogether::StorageConfigurationsController) # rubocop:disable RSpec/AnyInstance
        .to receive(:rebind_active_storage_service)
    end

    it 'sets the configuration as the platform active storage and redirects' do
      put activate_path(config)

      expect(response).to have_http_status(:see_other)
      expect(platform.reload.storage_configuration_id).to eq(config.id)
    end

    it 'shows an activation flash notice' do
      put activate_path(config)
      follow_redirect!

      # I18n value contains single quotes which Rails HTML-escapes to &#39;
      # in the rendered flash partial; use expect_html_content so Nokogiri
      # decodes entities before the string comparison.
      expect_html_content(
        I18n.t('better_together.storage_configurations.activated', name: config.name)
      )
    end
  end

  # ---------------------------------------------------------------------------
  # Access control — unauthenticated user
  # ---------------------------------------------------------------------------
  describe 'access control' do
    let!(:config) { create(:better_together_storage_configuration, platform:) }

    context 'when not logged in' do
      before { logout }

      # These routes are behind an `authenticated :user` Devise constraint scoped
      # to platform managers. Unauthenticated requests do not match the constraint
      # and receive 404 (Not Found) rather than a sign-in redirect.
      it 'returns 404 for index (route constraint requires platform manager)' do
        get index_path
        expect(response).to have_http_status(:not_found)
      end

      it 'returns 404 for new (route constraint requires platform manager)' do
        get new_path
        expect(response).to have_http_status(:not_found)
      end
    end
  end
end

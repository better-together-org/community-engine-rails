# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'BetterTogether::RobotsController', :as_platform_manager do
  let(:locale) { I18n.default_locale }
  let(:platform) { BetterTogether::Platform.find_by(host: true) || create(:better_together_platform, :host) }

  describe 'GET /:locale/host/platforms/:platform_id/robots' do
    it 'renders inherited global robots alongside platform overrides' do
      create(:robot, :global, identifier: 'translation', name: 'Global Translation Bot')
      create(:robot, platform:, identifier: 'assistant', name: 'Platform Assistant Bot')
      create(:robot, platform: create(:platform), identifier: 'assistant', name: 'Other Platform Bot')

      get better_together.platform_robots_path(platform, locale:)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Global Translation Bot')
      expect(response.body).to include('Platform Assistant Bot')
      expect(response.body).not_to include('Other Platform Bot')
      expect(response.body).to include(I18n.t('better_together.robots.readiness.openai_credentials'))
    end
  end

  describe 'POST /:locale/host/platforms/:platform_id/robots' do
    let(:robot_params) do
      {
        robot: {
          name: 'Platform Translation Bot',
          identifier: 'translation',
          robot_type: 'translation',
          provider: 'openai',
          default_model: '',
          default_embedding_model: '',
          system_prompt: 'Translate carefully.',
          active: '1',
          settings: {
            assume_model_exists: '1'
          }
        }
      }
    end

    it 'creates a platform-scoped robot and preserves structured settings' do
      expect do
        post better_together.platform_robots_path(platform, locale:), params: robot_params
      end.to change(BetterTogether::Robot, :count).by(1)

      robot = BetterTogether::Robot.order(:created_at).last
      expect(response).to redirect_to(better_together.platform_robots_path(platform, locale:))
      expect(robot.platform).to eq(platform)
      expect(robot.provider).to eq('openai')
      expect(robot.settings_hash[:assume_model_exists]).to be(true)
    end
  end

  describe 'PATCH /:locale/host/platforms/:platform_id/robots/:id' do
    let!(:robot) do
      create(:robot,
             platform:,
             identifier: 'translation',
             name: 'Initial Translation Bot',
             settings: { assume_model_exists: false, preserve_this_key: true })
    end

    it 'updates runtime fields and merges the managed settings key' do
      patch better_together.platform_robot_path(platform, robot, locale:), params: {
        robot: {
          name: 'Updated Translation Bot',
          provider: 'openai',
          default_model: 'gpt-4.1-mini',
          default_embedding_model: 'text-embedding-3-small',
          system_prompt: 'Use plain language.',
          active: '0',
          settings: { assume_model_exists: '1' }
        }
      }

      expect(response).to redirect_to(better_together.platform_robots_path(platform, locale:))
      expect(robot.reload.name).to eq('Updated Translation Bot')
      expect(robot.active).to be(false)
      expect(robot.settings_hash[:assume_model_exists]).to be(true)
      expect(robot.settings_hash[:preserve_this_key]).to be(true)
    end

    it 'does not allow editing a global fallback through a platform-scoped route' do
      global_robot = create(:robot, :global, identifier: 'translation', name: 'Global Translation Bot')

      get better_together.edit_platform_robot_path(platform, global_robot, locale:)

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'DELETE /:locale/host/platforms/:platform_id/robots/:id' do
    it 'destroys a platform-scoped robot' do
      robot = create(:robot, platform:, identifier: 'assistant')

      expect do
        delete better_together.platform_robot_path(platform, robot, locale:)
      end.to change(BetterTogether::Robot, :count).by(-1)

      expect(response).to redirect_to(better_together.platform_robots_path(platform, locale:))
    end
  end
end

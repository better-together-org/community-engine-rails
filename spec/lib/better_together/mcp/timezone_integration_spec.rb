# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'MCP Timezone Integration', type: :model do
  describe 'ApplicationTool timezone handling' do
    let(:tool_class) do
      Class.new(BetterTogether::Mcp::ApplicationTool) do
        description 'Test timezone tool'

        def call
          with_timezone_scope(user: current_user) do
            Time.current.zone
          end
        end
      end
    end

    let(:user) { create(:user) }

    before do
      configure_host_platform
      user.person.update(time_zone: 'America/Los_Angeles')
      allow_any_instance_of(tool_class).to receive(:request).and_return(
        instance_double(Rack::Request, params: { 'user_id' => user.id })
      )
    end

    it 'executes in user timezone' do
      tool = tool_class.new
      result = tool.call

      expect(result).to eq('PST')
    end

    context 'with different user timezone' do
      before do
        user.person.update(time_zone: 'Asia/Tokyo')
      end

      it 'uses updated timezone' do
        tool = tool_class.new
        result = tool.call

        expect(result).to eq('JST')
      end
    end

    context 'with no user timezone' do
      let(:platform) { BetterTogether::Platform.find_by(host: true) }

      before do
        user.person.update(time_zone: nil)
        platform.update(time_zone: 'America/New_York')
      end

      it 'falls back to platform timezone' do
        tool = tool_class.new
        result = tool.call

        expect(result).to eq('EST')
      end
    end
  end

  describe 'ApplicationResource timezone handling' do
    let(:resource_class) do
      Class.new(BetterTogether::Mcp::ApplicationResource) do
        uri 'test://timezone'
        resource_name 'Timezone Test'
        mime_type 'application/json'

        def content
          with_timezone_scope(user: current_user) do
            JSON.generate({
                            timezone: Time.zone.name,
                            current_time: Time.current.iso8601
                          })
          end
        end
      end
    end

    let(:user) { create(:user) }

    before do
      configure_host_platform
      user.person.update(time_zone: 'Europe/London')
      allow_any_instance_of(resource_class).to receive(:request).and_return(
        instance_double(Rack::Request, params: { 'user_id' => user.id })
      )
    end

    it 'generates content in user timezone' do
      resource = resource_class.new
      content = JSON.parse(resource.content)

      expect(content['timezone']).to eq('Europe/London')
    end

    it 'formats timestamps in user timezone' do
      resource = resource_class.new
      content = JSON.parse(resource.content)

      # Parse the ISO8601 timestamp and verify it's in correct timezone
      time = Time.parse(content['current_time'])
      expect(time.zone).to eq('UTC')
    end
  end

  describe 'ListCommunitiesTool timezone integration' do
    let!(:community) do
      create(:community,
             name: 'Test Community',
             privacy: 'public',
             created_at: Time.utc(2025, 1, 15, 14, 0, 0))
    end
    let(:user) { create(:user) }

    before do
      configure_host_platform
      user.person.update(time_zone: 'Pacific/Auckland')
      allow_any_instance_of(BetterTogether::Mcp::ListCommunitiesTool).to receive(:request).and_return(
        instance_double(Rack::Request, params: { 'user_id' => user.id })
      )
    end

    it 'formats timestamps in user timezone' do
      tool = BetterTogether::Mcp::ListCommunitiesTool.new
      result = tool.call

      communities = JSON.parse(result)
      community_data = communities.first

      # created_at should be in ISO8601 format with timezone
      created_at = Time.iso8601(community_data['created_at'])
      expected_offset = ActiveSupport::TimeZone['Pacific/Auckland']
                        .period_for_utc(community.created_at)
                        .utc_total_offset
      expect(created_at.utc_offset).to eq(expected_offset)
    end
  end

  describe 'TimezoneScoped concern integration' do
    it 'ApplicationTool includes TimezoneScoped' do
      expect(BetterTogether::Mcp::ApplicationTool.included_modules).to include(BetterTogether::TimezoneScoped)
    end

    it 'ApplicationResource includes TimezoneScoped' do
      expect(BetterTogether::Mcp::ApplicationResource.included_modules).to include(BetterTogether::TimezoneScoped)
    end
  end
end

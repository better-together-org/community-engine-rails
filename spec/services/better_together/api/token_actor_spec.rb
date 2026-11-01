# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Api::TokenActor do
  let(:platform) { BetterTogether::Platform.find_by!(host: true) }
  let(:operator) { create(:better_together_user, :confirmed, :platform_manager).person }
  let(:robot) { create(:robot, platform: platform) }
  let(:community) { create(:better_together_community) }
  let!(:grant) do
    create(:better_together_agent_grant, robot: robot, operator: operator, platform: platform,
                                         community: community, scopes: %w[read mcp_access])
  end
  let(:application) do
    create(:better_together_oauth_application, owner: operator, robot: robot, platform: platform,
                                               community: community, scopes: 'read mcp_access')
  end
  let(:token) { create(:better_together_oauth_access_token, :client_credentials, application: application, scopes: 'read write mcp_access') }

  before { Current.platform = platform }

  after { Current.reset }

  it 'resolves robot, operator and community from the token only' do
    actor = described_class.from_token(token)

    expect(actor.robot).to eq(robot)
    expect(actor.operator).to eq(operator)
    expect(actor.community).to eq(community)
  end

  it 'intersects token scopes with grant scopes' do
    expect(described_class.from_token(token).scopes).to contain_exactly('read', 'mcp_access')
  end

  it 'is nil for an application that is not bound to a robot' do
    plain = create(:better_together_oauth_application, owner: operator)
    plain_token = create(:better_together_oauth_access_token, :client_credentials, application: plain)

    expect(described_class.from_token(plain_token)).to be_nil
  end

  it 'is inactive without a live grant' do
    grant.update!(revoked_at: Time.current)

    expect(described_class.from_token(token)).not_to be_active
  end

  it 'ignores a grant that was made by someone other than the application owner' do
    other_operator = create(:better_together_user, :confirmed, :platform_manager).person
    application.update_columns(owner_id: other_operator.id) # rubocop:disable Rails/SkipsModelValidations

    expect(described_class.from_token(token.reload)).not_to be_active
  end

  it 'is inactive while the operator account is unconfirmed' do
    operator.user.update_columns(confirmed_at: nil) # rubocop:disable Rails/SkipsModelValidations

    expect(described_class.from_token(token)).not_to be_active
  end

  it 'is inactive when the request arrives on another platform' do
    Current.platform = create(:better_together_platform)

    expect(described_class.from_token(token)).not_to be_active
  end

  it 'is inactive when the request platform is unknown' do
    Current.platform = nil

    expect(described_class.from_token(token)).not_to be_active
  end

  it 'scopes the operator person to the credential community' do
    other = create(:better_together_community)
    described_class.from_token(token).apply_to_current!

    expect(operator.permitted_to?('update_community', other)).to be(false)
  end

  it 'attaches to MCP so a client_credentials agent token is not anonymous' do
    request = Rack::Request.new(Rack::MockRequest.env_for('/mcp/messages',
                                                          'HTTP_AUTHORIZATION' => "Bearer #{token.token}"))

    context = BetterTogether::Mcp::PunditContext.from_request_or_doorkeeper(request)

    expect(context).to be_authenticated
    expect(context.actor.robot).to eq(robot)
    expect(context.person.id).to eq(operator.id)
    expect(Current.credential_community).to eq(community)
  end
end

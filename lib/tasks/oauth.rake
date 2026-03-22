# frozen_string_literal: true

# rubocop:disable Metrics/BlockLength
namespace :better_together do
  namespace :oauth do
    desc 'Create default OAuth applications for n8n and management tool integration'
    task seed: :environment do
      puts 'Creating default OAuth applications...'

      platform = BetterTogether::Platform.host
      unless platform
        puts 'ERROR: No host platform found. Run platform setup first.'
        exit 1
      end

      # Find or use the first platform manager as the app owner
      owner = find_platform_manager(platform)
      unless owner
        puts 'ERROR: No platform manager found. Create a platform manager first.'
        exit 1
      end

      create_n8n_application(owner)
      create_management_tool_application(owner)
      create_webhook_application(owner)

      puts "\nDone! OAuth applications are ready for integration."
      puts 'Use the client ID and secret to configure your n8n credentials.'
    end

    desc 'List existing OAuth applications'
    task list: :environment do
      apps = BetterTogether::OauthApplication.all
      if apps.empty?
        puts 'No OAuth applications found.'
      else
        puts 'UID                                  Name                           Owner                Scopes'
        puts '-' * 120
        # rubocop:disable Style/FormatStringToken
        apps.each do |app|
          puts format('%-36s %-30s %-20s %s',
                      app.uid, app.name, app.owner&.name || 'none', app.scopes)
        end
        # rubocop:enable Style/FormatStringToken
      end
    end
  end
end
# rubocop:enable Metrics/BlockLength

def find_platform_manager(platform)
  # Find a person with platform management permission
  platform.community&.community_members&.find do |membership|
    membership.member&.permitted_to?('manage_platform')
  end&.member
end

# rubocop:disable Metrics/MethodLength, Metrics/AbcSize
def create_n8n_application(owner)
  app = BetterTogether::OauthApplication.find_or_initialize_by(
    name: 'n8n Workflow Automation'
  )

  if app.new_record?
    app.assign_attributes(
      owner: owner,
      redirect_uri: ENV.fetch('N8N_OAUTH_REDIRECT_URI',
                              'https://ai.btsdev.ca/rest/oauth2-credential/callback'),
      scopes: n8n_scopes,
      confidential: true
    )
    app.save!
    puts "  Created: #{app.name}"
    puts "    Client ID:     #{app.uid}"
    puts "    Client Secret: #{app.secret}"
    puts "    Scopes:        #{app.scopes}"
  else
    puts "  Exists:  #{app.name} (#{app.uid})"
  end
end

def create_management_tool_application(owner)
  app = BetterTogether::OauthApplication.find_or_initialize_by(
    name: 'BTS Management Tool'
  )

  if app.new_record?
    app.assign_attributes(
      owner: owner,
      redirect_uri: 'urn:ietf:wg:oauth:2.0:oob',
      scopes: management_tool_scopes,
      confidential: true
    )
    app.save!
    puts "  Created: #{app.name}"
    puts "    Client ID:     #{app.uid}"
    puts "    Client Secret: #{app.secret}"
    puts "    Scopes:        #{app.scopes}"
  else
    puts "  Exists:  #{app.name} (#{app.uid})"
  end
end

def create_webhook_application(owner)
  app = BetterTogether::OauthApplication.find_or_initialize_by(
    name: 'Platform Webhook Delivery'
  )

  if app.new_record?
    app.assign_attributes(
      owner: owner,
      redirect_uri: 'urn:ietf:wg:oauth:2.0:oob',
      scopes: 'read write',
      confidential: true
    )
    app.save!
    puts "  Created: #{app.name}"
    puts "    Client ID:     #{app.uid}"
    puts "    Client Secret: #{app.secret}"
  else
    puts "  Exists:  #{app.name} (#{app.uid})"
  end
end
# rubocop:enable Metrics/MethodLength, Metrics/AbcSize

def n8n_scopes
  %w[
    read write
    read_communities write_communities
    read_people
    read_events write_events
    read_posts write_posts
    read_conversations write_conversations
    read_metrics
    mcp_access
  ].join(' ')
end

def management_tool_scopes
  %w[
    read write admin
    read_communities write_communities
    read_people
    read_events write_events
    read_posts write_posts
    read_conversations write_conversations
    read_metrics write_metrics
    mcp_access
  ].join(' ')
end

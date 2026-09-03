# frozen_string_literal: true

# rubocop:disable Metrics/BlockLength
namespace :better_together do
  desc 'Provision a new tenant platform. ' \
       'Args: name (required), host_url (required), time_zone (default America/St_Johns), ' \
       'steward_email (optional), steward_password (optional), steward_name (optional). ' \
       'Example: rails better_together:provision_tenant[MyTenant,https://tenant.example.com,UTC,steward@example.com,SecurePass1!,Steward]'
  # rubocop:disable Metrics/BlockLength
  task :provision_tenant, %i[name host_url time_zone steward_email steward_password steward_name] => :environment do |_t, args|
    name       = args[:name]
    host_url   = args[:host_url]
    time_zone  = args.fetch(:time_zone, 'America/St_Johns')
    steward_email    = args[:steward_email]
    steward_password = args[:steward_password]
    steward_name     = args[:steward_name]

    abort 'ERROR: name is required. Usage: rails better_together:provision_tenant[name,host_url,...]' if name.blank?
    abort 'ERROR: host_url is required. Usage: rails better_together:provision_tenant[name,host_url,...]' if host_url.blank?

    steward = if steward_email.present? && steward_password.present?
                {
                  email: steward_email,
                  password: steward_password,
                  password_confirmation: steward_password,
                  name: steward_name
                }
              end

    puts "Provisioning tenant platform: #{name} (#{host_url})…"

    result = BetterTogether::TenantPlatformProvisioningService.call(
      name:,
      host_url:,
      time_zone:,
      steward:,
      privacy: 'private'
    )

    if result.success?
      puts "✅ Platform provisioned: #{result.platform.name} (#{result.platform.id})"
      puts "   Community : #{result.community&.name}"
      puts "   Domain    : #{result.domain&.hostname}"
      puts "   Steward   : #{result.steward_user&.email}" if result.steward_user
    else
      abort "❌ Provisioning failed:\n  #{result.errors.join("\n  ")}"
    end
  end
  # rubocop:enable Metrics/BlockLength
end
# rubocop:enable Metrics/BlockLength

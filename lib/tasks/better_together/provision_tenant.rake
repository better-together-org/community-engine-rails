# frozen_string_literal: true

# rubocop:disable Metrics/BlockLength
namespace :better_together do
  desc 'Provision a new tenant platform. ' \
       'Args: name (required), host_url (required), time_zone (default UTC), ' \
       'admin_email (optional), admin_password (optional), admin_name (optional). ' \
       'Example: rails better_together:provision_tenant[MyTenant,https://tenant.example.com,UTC,admin@example.com,SecurePass1!,Admin]'
  # rubocop:disable Metrics/BlockLength
  task :provision_tenant, %i[name host_url time_zone admin_email admin_password admin_name] => :environment do |_t, args|
    name       = args[:name]
    host_url   = args[:host_url]
    time_zone  = args.fetch(:time_zone, 'UTC')
    admin_email    = args[:admin_email]
    admin_password = args[:admin_password]
    admin_name     = args[:admin_name]

    abort 'ERROR: name is required. Usage: rails better_together:provision_tenant[name,host_url,...]' if name.blank?
    abort 'ERROR: host_url is required. Usage: rails better_together:provision_tenant[name,host_url,...]' if host_url.blank?

    admin = if admin_email.present? && admin_password.present?
              { email: admin_email, password: admin_password, name: admin_name }
            end

    puts "Provisioning tenant platform: #{name} (#{host_url})…"

    result = BetterTogether::TenantPlatformProvisioningService.call(
      name:,
      host_url:,
      time_zone:,
      admin:
    )

    if result.success?
      puts "✅ Platform provisioned: #{result.platform.name} (#{result.platform.id})"
      puts "   Community : #{result.community&.name}"
      puts "   Domain    : #{result.domain&.hostname}"
      puts "   Admin     : #{result.admin_user&.email}" if result.admin_user
    else
      abort "❌ Provisioning failed:\n  #{result.errors.join("\n  ")}"
    end
  end
  # rubocop:enable Metrics/BlockLength
end
# rubocop:enable Metrics/BlockLength

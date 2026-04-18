# frozen_string_literal: true

module BetterTogether
  # Base job for BetterTogether background execution.
  class ApplicationJob < ActiveJob::Base
    private

    def with_platform_runtime_context(platform_id: nil, tenant_schema: nil)
      context = ::BetterTogether::PlatformRuntimeContextResolver.for_platform(platform_id)

      ::Current.platform = context.platform
      ::Current.platform_domain = context.platform_domain
      ::Current.tenant_schema = tenant_schema.presence || context.tenant_schema
      yield
    ensure
      ::Current.reset
    end
  end
end

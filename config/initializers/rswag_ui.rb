# frozen_string_literal: true

# rswag-ui is a development/test dependency — skip gracefully in production host apps.
return unless defined?(Rswag::Ui)

Rswag::Ui.configure do |c|
  scope_path = BetterTogether.route_scope_path.present? ? BetterTogether.route_scope_path : ''
  c.openapi_endpoint "#{scope_path}/api/docs/v1/swagger.yaml", 'Community Engine API V1 Docs'

  # Host app additional swagger endpoints:
  #   BetterTogether.swagger_additional_endpoints << ['/api/docs/v1/swagger.yaml', 'My App API V1']
  BetterTogether.swagger_additional_endpoints.each do |path, title|
    c.openapi_endpoint path, title
  end
end

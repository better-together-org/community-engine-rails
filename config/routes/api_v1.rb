# frozen_string_literal: true

# API v1 resource routes (locale-aware for error messages and responses)
# Include this within the locale scope for consistent I18n support
namespace :api, defaults: { format: :json } do
  namespace :v1 do
    # People
    get 'people/me', to: 'people#me'
    jsonapi_resources :people
    # NOTE: Relationship routes omitted until all related resources exist

    # Communities
    jsonapi_resources :communities
    # NOTE: Relationship routes omitted until all related resources exist

    # Person Community Memberships
    jsonapi_resources :person_community_memberships, controller: 'person_community_memberships'

    # Roles (read-only)
    jsonapi_resources :roles
  end
end

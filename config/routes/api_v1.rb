# frozen_string_literal: true

# API v1 resource routes

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

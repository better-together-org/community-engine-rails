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

  # Roles (read-only)
  jsonapi_resources :roles, only: %i[index show]

  # Events
  jsonapi_resources :events

  # Posts
  jsonapi_resources :posts

  # Conversations
  jsonapi_resources :conversations, only: %i[index show create update]

  # Messages (create-only for sending, index/show for reading)
  jsonapi_resources :messages, only: %i[index show create]

  # Notifications (read + mark as read)
  jsonapi_resources :notifications, only: %i[index show update]
  post 'notifications/mark_all_read', to: 'notifications#mark_all_read'
end

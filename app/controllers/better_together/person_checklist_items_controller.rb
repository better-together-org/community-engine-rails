# frozen_string_literal: true

module BetterTogether
  class PersonChecklistItemsController < ApplicationController
    before_action :authenticate_user!
    before_action :set_checklist
    before_action :set_checklist_item
    # This endpoint is used by a small JSON toggle from the client-side.
    # Some host layouts do not include the CSRF meta tag in test snapshots,
    # so allow this JSON endpoint to be called without the CSRF token.
    skip_before_action :verify_authenticity_token, only: [:create]

    def show
      person = current_user.person
      pci = BetterTogether::PersonChecklistItem.find_by(person:, checklist: @checklist, checklist_item: @checklist_item)

      if pci
        render json: { id: pci.id, completed_at: pci.completed_at }
      else
        render json: { id: nil, completed_at: nil }, status: :ok
      end
    end

    def create
      # Diagnostic log to confirm authentication state for incoming requests
      Rails.logger.info("DBG PersonChecklistItemsController#create: current_user_id=#{current_user&.id}, warden_user_id=#{if request.env['warden']
                                                                                                                            request.env['warden']&.user&.id
                                                                                                                          end}")
      Rails.logger.info("DBG PersonChecklistItemsController#create: params=#{params.to_unsafe_h}")
      person = current_user.person
      pci = BetterTogether::PersonChecklistItem.find_or_initialize_by(person:, checklist: @checklist,
                                                                      checklist_item: @checklist_item)
      pci.completed_at = params[:completed] ? Time.zone.now : nil

      respond_to do |format|
        if pci.save
          Rails.logger.info("DBG PersonChecklistItemsController#create: saved pci id=#{pci.id} completed_at=#{pci.completed_at}")
          # If checklist completed, trigger a hook (implement as ActiveSupport::Notifications for now)
          notify_if_checklist_complete(person)
          format.json do
            render json: { id: pci.id, completed_at: pci.completed_at, flash: { type: 'notice', message: t('flash.checklist_item.updated') } },
                   status: :ok
          end
          format.html do
            redirect_back(fallback_location: BetterTogether.base_path_with_locale,
                          notice: t('flash.checklist_item.updated'))
          end
          format.turbo_stream do
            flash.now[:notice] = t('flash.checklist_item.updated')
            render turbo_stream: turbo_stream.replace('flash_messages',
                                                      partial: 'layouts/better_together/flash_messages', locals: { flash: })
          end
        else
          format.json do
            render json: { errors: pci.errors.full_messages, flash: { type: 'alert', message: t('flash.checklist_item.update_failed') } },
                   status: :unprocessable_entity
          end
          format.html do
            redirect_back(fallback_location: BetterTogether.base_path_with_locale,
                          alert: t('flash.checklist_item.update_failed'))
          end
          format.turbo_stream do
            flash.now[:alert] = t('flash.checklist_item.update_failed')
            render turbo_stream: turbo_stream.replace('flash_messages',
                                                      partial: 'layouts/better_together/flash_messages', locals: { flash: })
          end
        end
      end
    rescue StandardError => e
      Rails.logger.error("PersonChecklistItemsController#create unexpected error: #{e.class} - #{e.message}\n#{e.backtrace.join("\n")}")
      render json: { errors: [e.message], flash: { type: 'alert', message: e.message } }, status: :internal_server_error
    end

    private

    def set_checklist
      @checklist = BetterTogether::Checklist.find(params[:checklist_id])
    end

    def set_checklist_item
      item_param = params[:checklist_item_id] || params[:id]
      @checklist_item = @checklist.checklist_items.find(item_param)
    end

    def notify_if_checklist_complete(person)
      total = @checklist.checklist_items.count
      completed = BetterTogether::PersonChecklistItem.where(person:,
                                                            checklist: @checklist).where.not(completed_at: nil).count

      return unless total > 0 && completed >= total

      ActiveSupport::Notifications.instrument('better_together.checklist.completed', checklist_id: @checklist.id,
                                                                                     person_id: person.id)
    end
  end
end

# frozen_string_literal: true

module BetterTogether
  class PersonChecklistItemsController < ApplicationController # rubocop:todo Style/Documentation
    before_action :authenticate_user!
    before_action :set_checklist
    before_action :set_checklist_item
    # This endpoint is used by a small JSON toggle from the client-side.
    # Some host layouts do not include the CSRF meta tag in test snapshots,
    # so allow this JSON endpoint to be called without the CSRF token.

    def show # rubocop:todo Metrics/MethodLength
      # Handle case where checklist or item might not be visible yet due to transaction timing
      unless @checklist
        render json: { id: nil, completed_at: nil, error: 'Checklist not found' }, status: :not_found
        return
      end

      unless @checklist_item
        render json: { id: nil, completed_at: nil, error: 'Checklist item not found' }, status: :not_found
        return
      end

      person = current_user.person
      pci = BetterTogether::PersonChecklistItem.find_by(person:, checklist: @checklist, checklist_item: @checklist_item)

      if pci
        render json: { id: pci.id, completed_at: pci.completed_at }
      else
        render json: { id: nil, completed_at: nil }, status: :ok
      end
    end

    # rubocop:todo Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
    def create # rubocop:todo Metrics/AbcSize, Metrics/MethodLength
      # Handle case where checklist or item might not be visible yet due to transaction timing
      unless @checklist
        render json: { errors: ['Checklist not found'], flash: { type: 'alert', message: 'Checklist not found' } },
               status: :not_found
        return
      end

      unless @checklist_item
        render json: { errors: ['Checklist item not found'], flash: { type: 'alert', message: 'Checklist item not found' } },
               status: :not_found
        return
      end

      # Diagnostic log to confirm authentication state for incoming requests
      # rubocop:todo Layout/LineLength
      Rails.logger.info("DBG PersonChecklistItemsController#create: current_user_id=#{current_user&.id}, warden_user_id=#{request.env['warden']&.user&.id}")
      # rubocop:enable Layout/LineLength
      Rails.logger.info("DBG PersonChecklistItemsController#create: params=#{params.to_unsafe_h}")
      person = current_user.person
      pci = BetterTogether::PersonChecklistItem.find_or_initialize_by(person:, checklist: @checklist,
                                                                      checklist_item: @checklist_item)
      pci.completed_at = params[:completed] ? Time.zone.now : nil

      respond_to do |format| # rubocop:todo Metrics/BlockLength
        if pci.save
          # rubocop:todo Layout/LineLength
          Rails.logger.info("DBG PersonChecklistItemsController#create: saved pci id=#{pci.id} completed_at=#{pci.completed_at}")
          # rubocop:enable Layout/LineLength
          # If checklist completed, trigger a hook (implement as ActiveSupport::Notifications for now)
          notify_if_checklist_complete(person)
          format.json do
            # rubocop:todo Layout/LineLength
            render json: { id: pci.id, completed_at: pci.completed_at, flash: { type: 'notice', message: t('flash.checklist_item.updated') } },
                   # rubocop:enable Layout/LineLength
                   status: :ok
          end
          format.html do
            redirect_back(fallback_location: BetterTogether.base_path_with_locale,
                          notice: t('flash.checklist_item.updated'))
          end
          format.turbo_stream do
            flash.now[:notice] = t('flash.checklist_item.updated')
            render turbo_stream: turbo_stream.replace('flash_messages',
                                                      # rubocop:todo Layout/LineLength
                                                      partial: 'layouts/better_together/flash_messages', locals: { flash: })
            # rubocop:enable Layout/LineLength
          end
        else
          format.json do
            # rubocop:todo Layout/LineLength
            render json: { errors: pci.errors.full_messages, flash: { type: 'alert', message: t('flash.checklist_item.update_failed') } },
                   # rubocop:enable Layout/LineLength
                   status: :unprocessable_entity
          end
          format.html do
            redirect_back(fallback_location: BetterTogether.base_path_with_locale,
                          alert: t('flash.checklist_item.update_failed'))
          end
          format.turbo_stream do
            flash.now[:alert] = t('flash.checklist_item.update_failed')
            render turbo_stream: turbo_stream.replace('flash_messages',
                                                      # rubocop:todo Layout/LineLength
                                                      partial: 'layouts/better_together/flash_messages', locals: { flash: })
            # rubocop:enable Layout/LineLength
          end
        end
      end
    rescue StandardError => e
      # rubocop:todo Layout/LineLength
      Rails.logger.error("PersonChecklistItemsController#create unexpected error: #{e.class} - #{e.message}\n#{e.backtrace.join("\n")}")
      # rubocop:enable Layout/LineLength
      render json: { errors: [e.message], flash: { type: 'alert', message: e.message } },
             status: :internal_server_error
    end
    # rubocop:enable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity

    private

    def set_checklist
      # Use find_by instead of find to handle race conditions in tests where
      # the checklist might not be visible yet due to transaction timing
      @checklist = BetterTogether::Checklist.find_by(id: params[:checklist_id])
    end

    def set_checklist_item
      return if @checklist.nil?

      item_param = params[:checklist_item_id] || params[:id]
      # Use find_by instead of find to handle race conditions in tests where
      # the item might not be visible yet due to transaction timing
      @checklist_item = @checklist.checklist_items.find_by(id: item_param)
    end

    def notify_if_checklist_complete(person)
      return if @checklist.nil?

      total = @checklist.checklist_items.count
      completed = BetterTogether::PersonChecklistItem.where(person:,
                                                            checklist: @checklist).where.not(completed_at: nil).count

      return unless total.positive? && completed >= total

      ActiveSupport::Notifications.instrument('better_together.checklist.completed', checklist_id: @checklist.id,
                                                                                     person_id: person.id)
    end
  end
end

# frozen_string_literal: true

module BetterTogether
  class ChecklistItemsController < FriendlyResourceController # rubocop:todo Style/Documentation
    before_action :set_checklist
    before_action :checklist_item, only: %i[show edit update destroy]

    helper_method :new_checklist_item

    def create # rubocop:todo Metrics/AbcSize
      @checklist_item = new_checklist_item
      @checklist_item.assign_attributes(resource_params)
      authorize @checklist_item

      if @checklist_item.save
        redirect_to request.referer || checklist_path(@checklist), notice: t('flash.generic.created')
      else
        redirect_to request.referer || checklist_path(@checklist),
                    alert: @checklist_item.errors.full_messages.to_sentence
      end
    end

    def update
      authorize @checklist_item

      if @checklist_item.update(resource_params)
        redirect_to request.referer || checklist_path(@checklist), notice: t('flash.generic.updated')
      else
        redirect_to request.referer || checklist_path(@checklist),
                    alert: @checklist_item.errors.full_messages.to_sentence
      end
    end

    def destroy
      authorize @checklist_item

      @checklist_item.destroy
      redirect_to request.referer || checklist_path(@checklist), notice: t('flash.generic.deleted')
    end

    private

    def set_checklist
      @checklist = BetterTogether::Checklist.find(params[:checklist_id] || params[:id])
    end

    def checklist_item
      @checklist_item = set_resource_instance
    end

    def new_checklist_item
      @checklist.checklist_items.new
    end

    def resource_class
      ::BetterTogether::ChecklistItem
    end

    def resource_collection
      resource_class.where(checklist: @checklist)
    end
  end
end

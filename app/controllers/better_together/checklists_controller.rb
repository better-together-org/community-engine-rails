# frozen_string_literal: true

module BetterTogether
  class ChecklistsController < FriendlyResourceController # rubocop:todo Style/Documentation
    def create
      @checklist = resource_class.new(resource_params)
      authorize @checklist
      @checklist.creator = helpers.current_person if @checklist.respond_to?(:creator=)

      if @checklist.save
        redirect_to @checklist, notice: t('flash.generic.created', resource: t('resources.checklist'))
      else
        render :new, status: :unprocessable_entity
      end
    end

    def completion_status
      authorize resource_instance
      person = current_user&.person
      total = resource_instance.checklist_items.count
      completed = 0

      completed = resource_instance.person_checklist_items.where(person:).where.not(completed_at: nil).count if person

      render json: { total: total, completed: completed, complete: total.positive? && completed >= total }
    end

    private

    def resource_class
      ::BetterTogether::Checklist
    end
  end
end

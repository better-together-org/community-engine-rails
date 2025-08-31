# frozen_string_literal: true

module BetterTogether
  class ChecklistsController < FriendlyResourceController # rubocop:todo Style/Documentation
    def create
      @checklist = resource_class.new(resource_params)
      authorize @checklist
      @checklist.creator = helpers.current_person if @checklist.respond_to?(:creator=)

      if @checklist.save
        redirect_to @checklist, notice: t('flash.generic.created')
      else
        render :new, status: :unprocessable_entity
      end
    end

    private

    def resource_class
      ::BetterTogether::Checklist
    end
  end
end

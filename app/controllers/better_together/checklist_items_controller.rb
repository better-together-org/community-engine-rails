# frozen_string_literal: true

module BetterTogether
  class ChecklistItemsController < FriendlyResourceController # rubocop:todo Style/Documentation, Metrics/ClassLength
    before_action :set_checklist
    before_action :checklist_item, only: %i[show edit update destroy]

    helper_method :new_checklist_item

    def create # rubocop:todo Metrics/AbcSize, Metrics/MethodLength
      @checklist_item = new_checklist_item
      @checklist_item.assign_attributes(resource_params)
      authorize @checklist_item
      respond_to do |format|
        if @checklist_item.save
          format.html { redirect_to request.referer || checklist_path(@checklist), notice: t('flash.generic.created') }
          format.turbo_stream
        else
          format.html do
            redirect_to request.referer || checklist_path(@checklist),
                        alert: @checklist_item.errors.full_messages.to_sentence
          end
          format.turbo_stream do
            render turbo_stream: turbo_stream.replace(dom_id(new_checklist_item)) {
              render partial: 'form',
                     locals: { form_object: @checklist_item,
                               form_url: better_together.checklist_checklist_items_path(@checklist) }
            }
          end
        end
      end
    end

    def update # rubocop:todo Metrics/AbcSize, Metrics/MethodLength
      authorize @checklist_item
      respond_to do |format|
        if @checklist_item.update(resource_params)
          format.html { redirect_to request.referer || checklist_path(@checklist), notice: t('flash.generic.updated') }
          format.turbo_stream
        else
          format.html do
            redirect_to request.referer || checklist_path(@checklist),
                        alert: @checklist_item.errors.full_messages.to_sentence
          end
          format.turbo_stream do
            render turbo_stream: turbo_stream.replace(dom_id(@checklist_item)) {
              render partial: 'form',
                     locals: { checklist_item: @checklist_item,
                               form_url: better_together.checklist_checklist_item_path(@checklist,
                                                                                       @checklist_item) }
            }
          end
        end
      end
    end

    def destroy
      authorize @checklist_item

      @checklist_item.destroy
      respond_to do |format|
        format.html { redirect_to request.referer || checklist_path(@checklist), notice: t('flash.generic.deleted') }
        format.turbo_stream
      end
    end

    def position # rubocop:todo Metrics/AbcSize, Metrics/MethodLength
      authorize @checklist_item

      direction = params[:direction]
      sibling = if direction == 'up'
                  resource_class.where(checklist: @checklist).where('position < ?',
                                                                    @checklist_item.position).order(position: :desc).first # rubocop:disable Layout/LineLength
                elsif direction == 'down'
                  resource_class.where(checklist: @checklist).where('position > ?',
                                                                    @checklist_item.position).order(position: :asc).first # rubocop:disable Layout/LineLength
                end

      if sibling
        ActiveRecord::Base.transaction do
          a_pos = @checklist_item.position
          @checklist_item.update!(position: sibling.position)
          sibling.update!(position: a_pos)
        end
      end

      respond_to do |format|
        format.html { redirect_to request.referer || checklist_path(@checklist), notice: t('flash.generic.updated') }
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace(dom_id(@checklist, :checklist_items)) {
            render partial: 'better_together/checklist_items/checklist_item',
                   collection: @checklist.checklist_items.with_translations, as: :checklist_item
          }
        end
      end
    end

    def reorder # rubocop:todo Metrics/AbcSize, Metrics/MethodLength
      # Reordering affects the checklist as a whole; require permission to update the parent
      authorize @checklist, :update?

      ids = params[:ordered_ids] || []
      return head :bad_request unless ids.is_a?(Array)

      klass = resource_class

      klass.transaction do
        ids.each_with_index do |id, idx|
          item = klass.find_by(id: id, checklist: @checklist)
          next unless item

          item.update!(position: idx)
        end
      end

      respond_to do |format|
        format.json { head :no_content }
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace(dom_id(@checklist, :checklist_items)) {
            render partial: 'better_together/checklist_items/checklist_item',
                   collection: @checklist.checklist_items.with_translations, as: :checklist_item
          }
        end
      end
    end

    private

    def set_checklist
      key = params[:checklist_id] || params[:id]
      @checklist = if key.nil?
                     nil
                   else
                     # The checklists table doesn't have a direct `slug` column in this schema
                     # (friendly id slugs are stored in the `friendly_id_slugs` table), so avoid
                     # querying `slug` directly. Lookup by id or identifier instead.
                     BetterTogether::Checklist.where(id: key).or(BetterTogether::Checklist.where(identifier: key)).first
                   end
      raise ActiveRecord::RecordNotFound unless @checklist
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

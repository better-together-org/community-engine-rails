# frozen_string_literal: true

module BetterTogether
  class ChecklistItemsController < FriendlyResourceController # rubocop:todo Style/Documentation, Metrics/ClassLength
    before_action :set_checklist
    before_action :checklist_item, only: %i[show edit update destroy position]

    helper_method :new_checklist_item
    helper_method :checklist_items_for

    def create # rubocop:todo Metrics/AbcSize, Metrics/MethodLength
      @checklist_item = new_checklist_item
      @checklist_item.assign_attributes(resource_params)
      authorize @checklist_item
      respond_to do |format|
        if @checklist_item.save
          format.html do
            redirect_to request.referer || checklist_path(@checklist), notice: t('flash.generic.created')
          end
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
          format.html do
            redirect_to request.referer || checklist_path(@checklist), notice: t('flash.generic.updated')
          end
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
      # Reordering affects the checklist as a whole; require permission to update the parent
      authorize @checklist, :update?

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
          render turbo_stream: turbo_stream.replace(
            helpers.dom_id(@checklist, :checklist_items),
            partial: 'better_together/checklist_items/list',
            locals: { checklist: @checklist }
          )
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
          render turbo_stream: turbo_stream.replace(
            helpers.dom_id(@checklist, :checklist_items),
            partial: 'better_together/checklist_items/list',
            locals: { checklist: @checklist }
          )
        end
      end
    end

    private

    def set_checklist
      key = params[:checklist_id] || params[:id]
      @checklist = nil
      if key.present?
        @checklist = find_by_id_or_identifier(key) || find_by_translation_slug(key) || find_by_friendly_or_id(key)
      end

      raise ActiveRecord::RecordNotFound unless @checklist
    end

    def find_by_id_or_identifier(key)
      BetterTogether::Checklist.where(id: key).or(BetterTogether::Checklist.where(identifier: key)).first
    end

    def find_by_translation_slug(key)
      translation = Mobility::Backends::ActiveRecord::KeyValue::StringTranslation.where(
        translatable_type: 'BetterTogether::Checklist',
        key: 'slug',
        value: key
      ).includes(:translatable).last

      translation&.translatable
    rescue StandardError
      nil
    end

    def find_by_friendly_or_id(key)
      BetterTogether::Checklist.friendly.find(key)
    rescue StandardError
      BetterTogether::Checklist.find_by(id: key)
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

    # Returns a memoized relation (or array) of checklist items for a checklist and optional parent_id.
    # Views should call this helper instead of building policy_scope queries inline so ordering and
    # policy scoping remain consistent and memoized for a single request.
    def checklist_items_for(checklist, parent_id: nil) # rubocop:disable Metrics/MethodLength
      @__checklist_items_cache ||= {}
      key = [checklist.id, parent_id]
      return @__checklist_items_cache[key] if @__checklist_items_cache.key?(key)

      scope = policy_scope(::BetterTogether::ChecklistItem)
      scope = scope.where(checklist: checklist)
      scope = if parent_id.nil?
                scope.where(parent_id: nil)
              else
                scope.where(parent_id: parent_id)
              end

      # Ensure we enforce ordering by position regardless of any order applied by policy_scope
      scope = scope.with_translations.reorder(:position)

      @__checklist_items_cache[key] = scope
    end
  end
end

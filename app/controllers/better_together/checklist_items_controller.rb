# frozen_string_literal: true

module BetterTogether
  class ChecklistItemsController < FriendlyResourceController # rubocop:todo Style/Documentation, Metrics/ClassLength
    before_action :set_checklist
    before_action :checklist_item, only: %i[show edit update destroy position]

    helper_method :new_checklist_item

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
              # Move the LI node: remove the moved element and insert before/after the sibling
              begin
                a = @checklist_item
                b = sibling
                streams = []
                streams << turbo_stream.remove(helpers.dom_id(a))

                # If direction is up, insert before sibling; if down, insert after sibling
              if direction == 'up'
                streams << turbo_stream.before(helpers.dom_id(b), partial: 'better_together/checklist_items/checklist_item', locals: { checklist_item: a, checklist: @checklist, moved: true })
              else
                streams << turbo_stream.after(helpers.dom_id(b), partial: 'better_together/checklist_items/checklist_item', locals: { checklist_item: a, checklist: @checklist, moved: true })
              end

                render turbo_stream: streams
              rescue StandardError
                # Fallback: update only the inner list contents
                render turbo_stream: turbo_stream.update("#{helpers.dom_id(@checklist, :checklist_items)}",
                                                         partial: 'better_together/checklist_items/list_contents',
                                                         locals: { checklist: @checklist })
              end
        end
      end
    end

    def reorder # rubocop:todo Metrics/AbcSize, Metrics/MethodLength
      # Reordering affects the checklist as a whole; require permission to update the parent
      authorize @checklist, :update?

      ids = params[:ordered_ids] || []
      return head :bad_request unless ids.is_a?(Array)

      klass = resource_class

      # Capture previous order before we update positions so we can compute a minimal DOM update
      previous_order = @checklist.checklist_items.order(:position).pluck(:id)

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
            # Try a minimal DOM update: if exactly one item moved, remove it and insert before/after the neighbor.
            begin
              ordered = params[:ordered_ids].map(&:to_i)
              # previous_order holds the order before we updated positions
              current_before = previous_order

              # If nothing changed, no content
              if ordered == current_before
                head :no_content and return
              end

              # Detect single moved id (difference between arrays)
              moved = (ordered - current_before)
              removed = (current_before - ordered)

              if moved.size == 1 && removed.size == 1
                moved_id = moved.first
                moved_item = @checklist.checklist_items.find_by(id: moved_id)
                # Safety: if item not found, fallback
                unless moved_item
                  raise 'moved-missing'
                end

                # Where did it land?
                new_index = ordered.index(moved_id)

                streams = []
                # Remove original node first
                streams << turbo_stream.remove(helpers.dom_id(moved_item))

                # Append after the next element (neighbor at new_index + 1)
                neighbor_id = ordered[new_index + 1] if new_index
                if neighbor_id
                  neighbor = @checklist.checklist_items.find_by(id: neighbor_id)
                  if neighbor
                    streams << turbo_stream.after(helpers.dom_id(neighbor), partial: 'better_together/checklist_items/checklist_item', locals: { checklist_item: moved_item, checklist: @checklist, moved: true })
                    render turbo_stream: streams and return
                  end
                end

                # If neighbor not found (moved to end), append to the UL
                streams << turbo_stream.append("#{helpers.dom_id(@checklist, :checklist_items)} ul", partial: 'better_together/checklist_items/checklist_item', locals: { checklist_item: moved_item, checklist: @checklist, moved: true })
                render turbo_stream: streams and return
              end

              # Fallback: update inner contents for complex reorders
              render turbo_stream: turbo_stream.update("#{helpers.dom_id(@checklist, :checklist_items)}",
                                                       partial: 'better_together/checklist_items/list_contents',
                                                       locals: { checklist: @checklist })
            rescue StandardError
              render turbo_stream: turbo_stream.update("#{helpers.dom_id(@checklist, :checklist_items)}",
                                                       partial: 'better_together/checklist_items/list_contents',
                                                       locals: { checklist: @checklist })
            end
        end
      end
    end

    private

    def set_checklist
      key = params[:checklist_id] || params[:id]

      @checklist = nil
      if key.present?
        # Try direct id/identifier lookup first (fast)
        @checklist = BetterTogether::Checklist.where(id: key).or(BetterTogether::Checklist.where(identifier: key)).first

        # Fallbacks to mirror FriendlyResourceController behaviour: try translated slug lookups
        if @checklist.nil?
          begin
            # Try Mobility translation lookup across locales
            translation = Mobility::Backends::ActiveRecord::KeyValue::StringTranslation.where(
              translatable_type: 'BetterTogether::Checklist',
              key: 'slug',
              value: key
            ).includes(:translatable).last

            @checklist ||= translation&.translatable
          rescue StandardError
            # ignore DB/translation lookup errors and continue to friendly_id fallback
          end
        end

        if @checklist.nil?
          begin
            @checklist = BetterTogether::Checklist.friendly.find(key)
          rescue StandardError
            @checklist ||= BetterTogether::Checklist.find_by(id: key)
          end
        end
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

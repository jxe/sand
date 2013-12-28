# an abstract class that adds this thing where the cells slide to show placeholders,
# and the rows open up

class CalDragManager < DragManager

    def initialize(v, cv, dock, vc)
    	super(v, cv)
    	@dock_controller = dock
    	@dockView = dock.view
    	@dock = dock.collectionView
    	@vc = vc
    end

	def should_be_offmap? p
		inside_dock?
	end

    def inside_dock?
		gr.locationInView(@dock).inside?(@dock.bounds)
    end

	def flip_cell cell
		return if @flipped_cell == cell

		if @flipped_cell
			@flipped_cell.recover_from_being_placeholder
			@flipped_cell = nil
		end

		if cell
			@flipped_cell = @over_cell
			@over_cell.becomes_placeholder
		end
	end

	def on_drag_over_cell
		flip_cell @over_cell  #unless @vc.animations_running
	end

	def on_drag_hovered_section
		if @over_section and !@vc.section_open and !@vc.animations_running
		    @vc.animate_open @over_section 
		end
	end

	def on_drag_over_section
		if @was_over_section && @vc.section_open
			@vc.animate_close 
    	end
	end

end

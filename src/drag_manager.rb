# installs itself on a view
# maintains: 
#    @over_section, @over_cell, @over_path, 
#    @was_over_section, @was_over_cell, @was_over_path,
#    @vel, @gr, @v, @vc, @dragging
# moves the little image around
# supports tumble, snap, and fade for the little image at the end 
# events: 
#    on_drag_started, on_drag_ended, 
#    on_drag_hovered_section, on_drag_over_section
#    on_drag_over_cell

class DragManager
	attr_reader :v, :vc, :gr

	def initialize v, cv
		@v = v
		@cv = cv
	end

	def newGestureRecognizer(kls)
		@gr = kls.alloc.initWithTarget(self, action: :handleGesture)
		puts "gr initialized: #{@gr.inspect}"
		@gr.delegate = self
		@gr.addTarget(self, action: :handleGesture)
		@gr
	end

	# def gestureRecognizer(gr1, shouldRecognizeSimultaneouslyWithGestureRecognizer: gr2)
	# 	true
	# end

	def gestureRecognizerShouldBegin(gr)
		true
	end

	def should_be_offmap?
		false
	end

	def set_path_cell_and_section p
		if should_be_offmap?(p)
			@over_section, @over_path, @over_cell = nil, nil, nil
			return
		end

		@over_path = p && @cv.indexPathForItemAtPoint(p)
		@over_cell = @over_path && @cv.cellForItemAtIndexPath(@over_path)
		@over_section = p && @vc.section_map[p.y.to_i]
	end

	def handleGesture(gr = nil)
		@p = @gr.locationInView(@cv)
		@pv = @gr.locationInView(@v)
		# @pw = @gr.locationInView(@v.window)
		case @gr.state
		when UIGestureRecognizerStateBegan
			@cv.scrollEnabled = false
			@vc.update_map
			set_path_cell_and_section @p
			@dragging = on_drag_started
			@dragging.center = @pv
			@v.addSubview @dragging

		when UIGestureRecognizerStateChanged
	    	@dragging.center = @pv
	    	@was_over_section, @was_over_path, @was_over_cell = @over_section, @over_path, @over_cell
	    	set_path_cell_and_section @p
			slow_enough = if @gr.respond_to?(:velocityInView)
				@gr.velocityInView(@v).y.abs < 65.0
			else
				true
			end
			on_drag_hovered_section if slow_enough && @over_section
			on_drag_over_section if @was_over_section != @over_section
			on_drag_over_cell if @was_over_cell != @over_cell

		when UIGestureRecognizerStateEnded
			set_path_cell_and_section @p
			on_drag_ended
			@cv.scrollEnabled = true
		end
	end

	def animate_drag_img_tumble
		@vc.apply_gravity @dragging

		# @dragging.tumble completion: lambda{
		# 	@dragging.removeFromSuperview
		# 	@dragging = nil
		# }
	end

	def animate_drag_img_spring_to(cell)
		pt = cell.respond_to?(:center) ? cell.center : cell
		@vc.snap_to @dragging, pt
		Thread.new{
			sleep 1
			@dragging.removeFromSuperview
			@dragging = nil
		}
	end

	def animate_drag_img_fade
		@dragging.fade_out duration: 0.1, completion:lambda{
			@dragging.removeFromSuperview
			@dragging = nil
		}
	end

end

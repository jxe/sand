class DragToReorder < CalDragManager

	def on_drag_over_cell
    	over_special_section = (@limit_to_section == @over_section)
    	over_target = @over_cell && over_special_section
   		@dragging.layer.opacity = over_target ? 1.0 : 0.5
   		@drag_cell.hidden = !over_target

		super if @over_section == @limit_to_section and @over_cell != @drag_cell
	end

	def on_drag_hovered_section
		super if @over_section == @limit_to_section
	end

    def on_drag_over_section
    	#no op
	end


    def gestureRecognizerShouldBegin(gr)
    	return false if inside_dock?
		return false unless @vc.drag_to_reorder_enabled?
    	p = gr.locationInView(@cv)
		thing = @vc.thing_at_point(p)
		return true if thing and EKEvent === thing
		return false
    end

    def imageFromCell(cell)
	    UIGraphicsBeginImageContextWithOptions(cell.bounds.size, false, 0);
		cell.layer.renderInContext(UIGraphicsGetCurrentContext())
	    image = UIGraphicsGetImageFromCurrentImageContext()
	    UIGraphicsEndImageContext()
	    image
    end

	def on_drag_started
		sound "tock.m4a"
		@press_thing = @vc.thing_at_point(@p)
		@drag_path = @over_path
		@drag_cell = @over_cell
		@limit_to_section = @over_section
		@over_cell && @over_cell.ghost
		puts "ghosted..."
		@vc.animate_open @over_section

		# imgview = @drag_cell.contentView.viewWithTag(100)
		# draggable = UIImageView.alloc.initWithImage(imgview.image)
		draggable = UIImageView.alloc.initWithImage(imageFromCell(@drag_cell))
		draggable.frame = CGRectMake(0,0,60,60)
		draggable
	end

	def should_delete ev, &cb
		return cb.call(true) if ev.fast_delete?
		UI.confirm("Delete Event?", "Delete #{ev.title}?", "Delete", &cb)
	end

	def on_drag_ended
		@drag_cell.unghost
		flip_cell nil
		end_thing = @vc.thing_at_point(@p)

		puts "ENDED: over_section: #{@over_section}; @limit_to_section: #{@limit_to_section};	drag_path: #{@drag_path.inspect}"

    	over_special_section = (@limit_to_section == @over_section)
    	over_target = @over_cell && over_special_section

		if !over_target
			sound "wssh.m4a"
			should_delete @press_thing do |yes|
				if yes
	  				animate_drag_img_tumble
					@vc.animate_rm_and_close @press_thing
				else
					@drag_cell.hidden = false
					animate_drag_img_fade
					@vc.animate_close
				end
			end
		elsif @press_thing == end_thing
			@drag_cell.hidden = false
			animate_drag_img_fade
			@vc.animate_close
		else
			sound "blip.m4a"
			# animate_drag_img_spring_to @over_cell
			@vc.animate_mv_and_close(@press_thing, end_thing, @dragging)
		end
	end

end

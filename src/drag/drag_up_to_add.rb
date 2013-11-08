class DragUpToAdd < CalDragManager

	def gestureRecognizerShouldBegin(gr)
		vel = @gr.velocityInView(@dock)
        return false unless vel.x.abs < vel.y.abs and inside_dock?
        position = gr.locationInView(@dock)
		translation = @gr.translationInView(@dock)
		origin = CGPointMake(position.x - translation.x, position.y - translation.y)
		@dock_path = @dock.indexPathForItemAtPoint(origin)
		puts "got path: #{@dock_path.inspect}"
		return false unless @dock_path
		@dock_path ? true : false
		cell = @dock.cellForItemAtIndexPath(@dock_path)
		@text = cell.contentView.viewWithTag(102).text
		@dock_item = cell.dock_item
		return true unless @text =~ /upcarret/
		UI.menu ["Get DockItems"] do |chose|
			case chose
			when /Get/
				@dock_controller.go_to_url nil, "http://nxhx.org/hourglass/"
			end
		end
		return false
	end

	def on_drag_started
		cell = @dock.cellForItemAtIndexPath(@dock_path)
		@text = cell.contentView.viewWithTag(102).text
		img = cell.contentView.viewWithTag(100).image
		draggable = UIImageView.alloc.initWithImage(img)
		draggable.frame = CGRectMake(0,0,60,60)
		draggable
	end

	def gestureRecognizer(gr, shouldBeRequiredToFailByGestureRecognizer: gr2)
		# let's take precendence
		true unless UILongPressGestureRecognizer === gr2
	end

	# def on_drag_ended2
	# 	flip_cell nil
	# 	return animate_drag_img_tumble if inside_dock?
	# 	placeholder = @vc.thing_at_point(@p)
	# 	unless placeholder
	# 		animate_drag_img_tumble
	# 		@vc.animate_close
	# 	end


	# 	sound "tick.m4a"
	# 	event = @dock_item.fresh_event_at(placeholder.startTime)

	# 	...

	# 	@dock_item.configure_event(event) do |result|
	# 		result == :failed ? @vc.animate_discard(event) : @vc.reload_event(event)
	# 	end
	# end

	def on_drag_ended
		flip_cell nil
		return animate_drag_img_tumble if inside_dock?
		placeholder = @vc.thing_at_point(@p)

		if !placeholder
			animate_drag_img_tumble
			@vc.animate_close
			return
		end

		sound "tick.m4a"
		before_event = EKEvent === placeholder && placeholder

		if @dock_item
			ev = @dock_item.event_at(placeholder)
			@vc.animate_add_event(ev, before_event, @dragging)
			return
		end


		# below only used for 'friend' and 'appt'

		@vc.with_person_and_title_for_droptext @text do |person, title|
			unless title
				animate_drag_img_tumble
				@vc.animate_close
				return
			end

			ev = Event.add_event(placeholder.startDate, person, title)
			@vc.animate_add_event(ev, before_event, @dragging)
		end
	end

end

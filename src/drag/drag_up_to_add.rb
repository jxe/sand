class DragUpToAdd < CalDragManager

	def gestureRecognizerShouldBegin(gr)
		vel = @gr.velocityInView(@dock)
        return false unless vel.x.abs < vel.y.abs and inside_dock?
        position = gr.locationInView(@dock)
		translation = @gr.translationInView(@dock)
		origin = CGPointMake(position.x - translation.x, position.y - translation.y)
		@dock_path = @dock.indexPathForItemAtPoint(origin)
		puts "got path: #{@dock_path.inspect}"
		@dock_path ? true : false
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

	def on_drag_ended
		# @vc.animate_close
		flip_cell nil
		return animate_drag_img_tumble if inside_dock?

		puts "on_drag_ended, not inside dock"

		if placeholder = @vc.thing_at_point(@p)
			puts "on_drag_ended, placeholder #{placeholder.inspect}"
			@vc.with_person_and_title_for_droptext @text do |person, title|
				if title
					sound "tick.m4a"
					case placeholder
					when Placeholder
						puts ">animate_add_and_close"
						@vc.animate_add_and_close placeholder, person, title, @dragging
						# animate_drag_img_spring_to @over_cell.layer.modelLayer.position
						puts "<animate_add_and_close"
					when EKEvent
						puts ">animate_insert_and_close"
						# animate_drag_img_spring_to @over_cell
						@vc.animate_insert_and_close placeholder, person, title, @dragging
						puts "<animate_insert_and_close"
					end
				else
					animate_drag_img_tumble
					@vc.animate_close
				end
			end
		else
			animate_drag_img_tumble
			@vc.animate_close
		end
	end

end

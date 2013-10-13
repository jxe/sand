class UpcomingCollectionView < UICollectionView

	def startDragging(p, cell, &cb)
		@dragging = true
		@dragging_cb = cb
		imgview = cell.contentView.viewWithTag(100)
		@dragging_img = UIImageView.alloc.initWithImage(imgview.image)
		@dragging_img.frame = CGRect.make(origin: @dragging_img.frame.origin, size: CGSizeMake(80,80))
		@dragging_img.center = p
		self.scrollEnabled = false
		self.userInteractionEnabled = true
		self.addSubview(@dragging_img)
	end

	def touchesBegan(touches, withEvent: event)
		puts "began"
		super
	end

	def touchesCancelled(touches, withEvent: event)
		super
	end

	def touchesMoved(touches, withEvent: event)
		return super unless @dragging
		@dragging_img.center = touches.anyObject.locationInView(self)
	end

	def touchesEnded(touches, withEvent: event)
		puts "ended"
		return super unless @dragging
		@dragging = false
		@dragging_img.removeFromSuperview
		@dragging_img = nil
		self.scrollEnabled = true
		# self.userInteractionEnabled = false
		@dragging_cb && @dragging_cb.call(touches.anyObject.locationInView(self))
		@dragging_cb = nil
		super
	end

end

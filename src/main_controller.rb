LIVE2 = []

class MainController < UIViewController

	def viewDidLoad
		view.gestureRecognizers[0].addTarget(self, action: :dragon)
		view.gestureRecognizers[0].delegate = self
		# toolbar = 
		# size = CGSizeMake(toolbar.frame.size.width, 80)
		# origin = CGPointMake(toolbar.frame.origin.x, toolbar.frame.origin.y - 50)
		# toolbar.frame = CGRect.make(origin: origin, size: size)
		super
	end

	def viewWillLayoutSubviews
		super
		# view.viewWithTag(211).frame = CGRectMake(0.0, 514.0, 320.0, 54.0)
	end

	def gestureRecognizerShouldBegin(gr)
		vel = gr.velocityInView(view)
        return vel.x.abs < vel.y.abs
	end

	def dragon
		gr = view.gestureRecognizers[0]
		pt = gr.locationInView(view)
		case gr.state
		when UIGestureRecognizerStateBegan
			dock = DockController.instance.collectionView
			dockFrame = dock.superview.superview.frame
			return gr.reset unless pt.inside?(dockFrame)
			pt = gr.locationInView(dock)
			path = dock.indexPathForItemAtPoint(pt)
			cell = dock.cellForItemAtIndexPath(path)
			return gr.reset unless cell
			imgview = cell.contentView.viewWithTag(100)
			@text = cell.contentView.viewWithTag(102).text
			@img = UIImageView.alloc.initWithImage(imgview.image)
			@img.frame = CGRect.make(origin: @img.frame.origin, size: CGSizeMake(80,80))
			@img.center = gr.locationInView(view)
			view.addSubview(@img)

		when UIGestureRecognizerStateChanged
			# LATER: detect hovers and ask for hit targets...
			# puts "dragging! #{dockFrame.inspect}"
			return unless @img
			@img.center = gr.locationInView(view)
			# upcoming = UpcomingController.instance
			# point = gr.locationInView(upcoming.collectionView)
			# upcoming.highlight_droptarget(point)

		when UIGestureRecognizerStateEnded
			puts "dropped!"
			upcoming = UpcomingController.instance
			# upcoming.unhighlight_droptargets
			return unless @text

			if @img
				@img.removeFromSuperview
				@img = nil
			end

			dock = DockController.instance.collectionView
			dockFrame = dock.superview.superview.frame
			pt = gr.locationInView(view)
			return if pt.inside?(dockFrame)

			point = gr.locationInView(upcoming.collectionView)
			upcoming.dropped(@text, point)
		end
	end


end

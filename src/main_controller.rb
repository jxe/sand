LIVE2 = []

class MainController < UIViewController

	def viewDidLoad
		view.gestureRecognizers[0].addTarget(self, action: :dragon)
		view.gestureRecognizers[0].delegate = self
		super
	end

	def viewWillLayoutSubviews
		super
		@upcoming ||= UpcomingController.instance
		@gr = view.gestureRecognizers[0]
		@dock = DockController.instance.collectionView
		@dockFrame = @dock.superview.superview.frame
		@upcoming_cv = @upcoming.collectionView
	end

	def gestureRecognizerShouldBegin(gr)
		vel = gr.velocityInView(view)
        return false unless vel.x.abs < vel.y.abs
		pt = gr.locationInView(view)
		return false unless pt.inside?(@dockFrame)
		path = @dock.indexPathForItemAtPoint(gr.locationInView(@dock))
		return false unless path
		return true
	end

	def dragon
		pt = @gr.locationInView(view)

		case @gr.state
		when UIGestureRecognizerStateBegan
			pt = @gr.locationInView(@dock)
			path = @dock.indexPathForItemAtPoint(pt)
			cell = @dock.cellForItemAtIndexPath(path)
			imgview = cell.contentView.viewWithTag(100)
			@text = cell.contentView.viewWithTag(102).text
			@img = UIImageView.alloc.initWithImage(imgview.image)
			@img.frame = CGRect.make(origin: @img.frame.origin, size: CGSizeMake(80,80))
			@img.center = @gr.locationInView(view)
			@upcoming.dragStart
			view.addSubview(@img)

		when UIGestureRecognizerStateChanged
			return @gr.reset unless @img
			@img.center = pt if @img
			@upcoming.dragOver(@text, pt.inside?(@dockFrame) ? nil : @gr.locationInView(@upcoming_cv))

		when UIGestureRecognizerStateEnded
			return unless @text
			@img.removeFromSuperview if @img
			@img = nil
			return @upcoming.dragCanceled if pt.inside?(@dockFrame)
			point = @gr.locationInView(@upcoming.collectionView)
			@upcoming.dropped(@text, point)
		end
	end


end

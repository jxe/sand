LIVE2 = []

class MainController < UIViewController

	def viewDidLoad
		view.gestureRecognizers[0].addTarget(self, action: :dragon)

		super
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

		when UIGestureRecognizerStateEnded
			puts "dropped!"
			return unless @text
			upcoming = UpcomingController.instance
			point = gr.locationInView(upcoming.collectionView)
			upcoming.dropped(@text, point)
			return unless @img
			@img.removeFromSuperview
			@img = nil

		end
	end


end

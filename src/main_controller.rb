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
			if pt.inside?(dockFrame)
				# really started, from inside the dock
				puts "drag started! #{dockFrame.inspect}"
				pt = gr.locationInView(dock)
				path = dock.indexPathForItemAtPoint(pt)
				cell = dock.cellForItemAtIndexPath(path)
				puts "got cell: #{cell.inspect}"
				imgview = cell.contentView.viewWithTag(100)
				@img = UIImageView.alloc.initWithImage(imgview.image)
				@img.center = gr.locationInView(view)
				view.addSubview(@img)

				# fetch hit targets from target
				# get the img from the cell that we started on
				# put the img in the overlaypane

			else
				gr.reset
			end
		when UIGestureRecognizerStateChanged
			puts "dragging! #{dockFrame.inspect}"
			if @img
				@img.center = gr.locationInView(view)
			end
				# hit detection... light up targets


		when UIGestureRecognizerStateEnded
			puts "dropped! #{dockFrame.inspect}"
			if @img
				@img.removeFromSuperview
				@img = nil
			end
			# ask row to open and reregister hit targets

		end
	end


end

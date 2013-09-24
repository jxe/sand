class PauseController < UIViewController

	def viewDidLoad
		super
	    view.addGestureRecognizer(UIPanGestureRecognizer.alloc.initWithTarget(self, action: :swipeHandler))
	end

	def swipeHandler sender = nil
		sideMenu.showFromPanGesture(sender)
	end

	def back_to_cal sender = nil
		sideMenu.show
	end

end

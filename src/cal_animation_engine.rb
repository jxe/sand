class CalAnimationEngine

	attr_reader :calViewController, :calView, :dockView, 
		:longPressRecognizer, :dragUpRecognizer

	def initialize calViewController, dockView
		@calViewController = calViewController
		@calView = @calViewController.collectionView
		@dockView = dockView
		@longPressRecognizer = @calView.gestureRecognizers[2]
		@dragUpRecognizer = #...

		@longPressRecognizer.delegate = self
		@dragUpRecognizer.delegate = self
		@longPressRecognizer.addTarget(self, action: :longPress)
	end
	
end

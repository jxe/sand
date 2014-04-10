class DockController < UICollectionViewController
	include ViewControllerImprovements
	attr_accessor :drag_up_to_add

	############
	# lifecycle

	def willMoveToParentViewController(cal)
		super
	end

	def didMoveToParentController(cal)
		super
	end

	def size_yourself_bro(cal)
		# dock_height = 63
		dock_height = 71
		dock_y = cal.view.frame.size.height - dock_height
		puts "size yourself called: #{dock_y}"
		view.frame = CGRectMake(0, dock_y, cal.view.frame.size.width, dock_height)
		view.autoresizingMask = UIViewAutoresizingFlexibleTopMargin
	end

	def viewWillAppear(animated=nil)
		super
		on_notification 'ReloadDock' do |x|
			puts "observed!"
		    collectionView.reloadData
		end
	end

	def viewWillDisappear(animated)
		super
	end

	def viewDidLoad
		super
		@@instance = self
		collectionView.draggable = true
		collectionView.deletable = true
		collectionView.delegate = self
		collectionView.dataSource = self

		# blurLayer = CALayer.layer
		# filter = CIFilter.filterWithName("CIGaussianBlur")
		# filter.setDefaults
		# blurLayer.backgroundFilters = [filter]
		# collectionView.setWantsLayer(true)

		@gradient = CAGradientLayer.layer
		@gradient.frame = CGRectMake(0,0,320,180)
		@gradient.endPoint = [0.5, 0.4]
		# @gradient.endPoint = [0.5, 0.01]
		# sandClear = UIColor.colorWithHue(0.12, saturation:0.62, brightness:0.7, alpha:0.6)
		# startColor = UIColor.colorWithHue(0.12, saturation:0.32, brightness:0.28, alpha:0.95)

		#sandClear = UIColor.colorWithHue(0.12, saturation:0.0, brightness:0.7, alpha:0.6)
		#startColor = UIColor.colorWithHue(0.12, saturation:0.0, brightness:0.28, alpha:0.95)
		sandClear = UIColor.colorWithHue(0.12, saturation:0.0, brightness:1.0, alpha:0.8)
		startColor = UIColor.colorWithHue(0.12, saturation:0.0, brightness:1.0, alpha:1.0)

		# UIColor.colorWithWhite(0.9, alpha: 1.0)
		# gradient.colors = [startColor.CGColor, sandClear.CGColor]
		@gradient.colors = [sandClear.CGColor, startColor.CGColor]

		v = UIView.alloc.initWithFrame(collectionView.bounds)
		v.layer.insertSublayer(@gradient, atIndex:0)
		collectionView.backgroundView = v

		@dtgr = UITapGestureRecognizer.alloc.initWithTarget(self, action: :singleTap)
		@dtgr.numberOfTapsRequired = 1
		collectionView.addGestureRecognizer(@dtgr)
	end

	def singleTap
		case @dtgr.state
		when UIGestureRecognizerStateEnded
			pt = @dtgr.locationInView(collectionView)
			path = collectionView.indexPathForItemAtPoint(pt)
			cell = path && collectionView.cellForItemAtIndexPath(path)
			return unless cell
			if cell.system_item
				go_to_url nil, "http://nxhx.org/hourglass/"
			elsif cell.dock_item.store_url
				NSLog "going to: %@", cell.dock_item.store_url
				go_to_url nil, cell.dock_item.store_url
			end
		end
	end

	def webView(wv, shouldStartLoadWithRequest: req, navigationType: type)
		if req.URL.scheme =~ /sandapp/
			App.delegate.process_sand_url(req.URL, self)
			false
		else
			true
		end
	end

	def self.instance
		@@instance
	end

	##############
	# data source

	def unhighlight
		MLPSpotlight.removeSpotlightsInView(view.superview)
	end

	def highlight
		MLPSpotlight.addSpotlightInView(view.superview, atPoint:view.center)
	end

	def collectionView(cv, canMoveItemAtIndexPath: path)
		can = path.row >= 1 and path.row < DockItem.visible.size + 1
		highlight if can
		can
	end

	def collectionView(cv, moveItemAtIndexPath:path0, toIndexPath:path1)
		DockItem.move(path0.row - 1, path1.row - 1)
		unhighlight
	end

	def collectionView(cv, canMoveItemAtIndexPath:path0, toIndexPath:path1)
		path0.row >= 1 and path1.row >= 1 and path1.row < DockItem.visible.size + 1
	end

	def collectionView(cv, deleteItemAtIndexPath: path)
		DockItem.visible[path.row - 1].hide!
		unhighlight
	end




	def numberOfSectionsInCollectionView(cv)
		1
	end

	def collectionView(cv, numberOfItemsInSection: section)
		DockItem.visible.size + 1
	end

	def collectionView(cv, cellForItemAtIndexPath: path)
		cell = cv.dequeueReusableCellWithReuseIdentifier('DockItem', forIndexPath:path)
		extras = DockItem.visible

		case path.row
		when 0
			cell.system_item = "appt"
		else
			cell.dock_item = extras[path.row - 1]
		end

		cell
	end

end

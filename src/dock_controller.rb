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
		dock_height = 63
		dock_y = cal.view.frame.size.height - dock_height
		puts "size yourself called: #{dock_y}"
		view.frame = CGRectMake(0, dock_y, cal.view.frame.size.width, dock_height)
	end

	def viewWillAppear(animated=nil)
		super
		observe 'ReloadDock' do |x|
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
		collectionView.delegate = self
		collectionView.dataSource = self

		# blurLayer = CALayer.layer
		# filter = CIFilter.filterWithName("CIGaussianBlur")
		# filter.setDefaults
		# blurLayer.backgroundFilters = [filter]
		# collectionView.setWantsLayer(true)

		gradient = CAGradientLayer.layer
		gradient.frame = collectionView.frame
		gradient.endPoint = [0.5, 0.07]
		startColor = UIColor.colorWithHue(0.12, saturation:0.32, brightness:0.28, alpha:0.95)
		sandClear = UIColor.colorWithHue(0.12, saturation:0.22, brightness:1.0, alpha:0.6)
		# UIColor.colorWithWhite(0.9, alpha: 1.0)
		# gradient.colors = [startColor.CGColor, sandClear.CGColor]
		gradient.colors = [sandClear.CGColor, startColor.CGColor]

		v = UIView.alloc.initWithFrame(collectionView.bounds)
		v.layer.insertSublayer(gradient, atIndex:0)
		collectionView.backgroundView = v

		@dtgr = UITapGestureRecognizer.alloc.initWithTarget(self, action: :doubleTap)
		@dtgr.numberOfTapsRequired = 2
		collectionView.addGestureRecognizer(@dtgr)
	end

	def doubleTap
		case @dtgr.state
		when UIGestureRecognizerStateEnded
			pt = @dtgr.locationInView(collectionView)
			puts "pt: #{pt.inspect}"
			path = collectionView.indexPathForItemAtPoint(pt)
			puts "path: #{path.inspect}"
			cell = path && collectionView.cellForItemAtIndexPath(path)
			options = ["Get More DockItems"]
			options << "Hide #{cell.dock_item.title}" if cell and cell.dock_item
			menu options do |chose|
				case chose
				when /More/
					go_to_url nil, "http://nxhx.org/hourglass/"
				when /Hide/
					cell.dock_item.hide!
					collectionView.reloadData
				end
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


	def collectionView(cv, canMoveItemAtIndexPath: path)
		path.row >= 1
	end

	def collectionView(cv, moveItemAtIndexPath:path0, toIndexPath:path1)
		DockItem.move(path0.row - 1, path1.row - 1)
	end

	def collectionView(cv, canMoveItemAtIndexPath:path0, toIndexPath:path1)
		path0.row >= 1 and path1.row >= 1
	end

	# def collectionView(cv, alterTranslation:translation)
	# end

	# def collectionView(cv, transformForDraggingItemAtIndexPath:path, duration: duration)
	# 	return
	# end




	def numberOfSectionsInCollectionView(cv)
		1
	end

	def collectionView(cv, numberOfItemsInSection: section)
		DockItem.visible.size + 2
	end

	def collectionView(cv, cellForItemAtIndexPath: path)
		cell = cv.dequeueReusableCellWithReuseIdentifier('DockItem', forIndexPath:path)
		extras = DockItem.visible

		case path.row
		when 0
			cell.system_item = "appt"
		when extras.size + 1
			cell.system_item = "upcarret"
		else
			cell.dock_item = extras[path.row - 1]
		end

		cell
	end

end

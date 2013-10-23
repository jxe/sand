class DockController < UICollectionViewController
	include ViewControllerImprovements
	attr_accessor :drag_up_to_add

	############
	# lifecycle

	def willMoveToParentViewController(cal)
		dock_height = 53
		dock_y = cal.view.frame.size.height - dock_height
		collectionView.frame = CGRectMake(0, dock_y, cal.view.frame.size.width, dock_height)
		cal.view.addSubview(collectionView)
	end

	def viewDidLoad
		super
		@@instance = self
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

	def process_sand_url url
		case spec = url.resourceSpecifier
		when /^reset-dock$/
			dismissViewController
			BW::UIAlertView.default({
			  :title               => "Reset Dock",
			  :message             => "Reset Dock to Factory Defaults?",
			  :buttons             => ["Cancel", "Engage"],
			  :cancel_button_index => 0
			}) do |alert|
			  unless alert.clicked_button.cancel?
				DockItem.load_defaults
				collectionView.reloadData
			  end
			end.show


		when /^dockitem\?(.*)$/
			begin
				DockItem.install($1.URLQueryParameters)
			rescue Exception => e
				BW::UIAlertView.default(:title => e.message)
			end
			dismissViewController
			collectionView.reloadData
		else
			BW::UIAlertView.default(:title => "Unrecognized sandapp: URL")
		end
	end

	def webView(wv, shouldStartLoadWithRequest: req, navigationType: type)
		req.URL.scheme =~ /sandapp/ ? process_sand_url(req.URL) : true
	end

	def self.instance
		@@instance
	end

	##############
	# data source

	def numberOfSectionsInCollectionView(cv)
		1
	end

	def collectionView(cv, numberOfItemsInSection: section)
		DockItem.visible.size + 2
	end

	def collectionView(cv, cellForItemAtIndexPath: path)
		cell = cv.dequeueReusableCellWithReuseIdentifier('DockItem', forIndexPath:path)

		case path.row
		when 0
			cell.system_item = "appt"
		when 1
			cell.system_item = "friend"
		else
			cell.dock_item = DockItem.visible[path.row - 2]
		end

		cell
	end

end

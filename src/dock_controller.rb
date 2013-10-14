class DockController < UICollectionViewController

	############
	# lifecycle

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
		gradient.frame = collectionView.bounds
		gradient.endPoint = [0.5, 0.3]
		startColor = UIColor.colorWithHue(0.12, saturation:0.32, brightness:0.28, alpha:0.95)
		sandClear = UIColor.colorWithHue(0.12, saturation:0.22, brightness:1.0, alpha:0.6)
		# UIColor.colorWithWhite(0.9, alpha: 1.0)
		gradient.colors = [startColor.CGColor, sandClear.CGColor]

		v = UIView.alloc.initWithFrame(collectionView.bounds)
		v.layer.insertSublayer(gradient, atIndex:0)
		collectionView.backgroundView = v
	end

	def self.instance
		@@instance
	end

	##############
	# data source

	def numberOfSectionsInCollectionView(cv)
		1
	end

	DEFAULT_DOCK = [
		"appt",
		"a friend", 

		"quiet", 
		"exercise", 
		"cooking",
		"sunshine", 
		"work", 
	]

	def collectionView(cv, numberOfItemsInSection: section)
		DEFAULT_DOCK.size
	end

	def setup_event_cell(cv, path, cell)
		imageview = cell.contentView.viewWithTag(100)
		personlabel = cell.contentView.viewWithTag(102)
		comboview = cell.contentView.viewWithTag(112)
		l = comboview.layer
		l.masksToBounds = false
		l.cornerRadius = 8
		l.shadowOffset = CGSizeMake(0, 2)
		l.shadowRadius = 1.8
		l.shadowOpacity = 0.7
		l.shadowColor = UIColor.blackColor.CGColor
		l.shadowPath = UIBezierPath.bezierPathWithRoundedRect(l.bounds, cornerRadius:8).CGPath
		personlabel.text = DEFAULT_DOCK[path.row]
		imageview.image = Event.image_from_title(personlabel.text)
		cell
	end

	def collectionView(cv, cellForItemAtIndexPath: path)
		cell = cv.dequeueReusableCellWithReuseIdentifier('Appt', forIndexPath:path)
		return setup_event_cell(cv, path, cell)
	end

end

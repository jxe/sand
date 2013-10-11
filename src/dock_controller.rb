class DockController < UICollectionViewController

	############
	# lifecycle

	def viewDidLoad
		super
		@@instance = self
		collectionView.delegate = self
		collectionView.dataSource = self

		blurLayer = CALayer.layer
		filter = CIFilter.filterWithName("CIGaussianBlur")
		filter.setDefaults
		blurLayer.backgroundFilters = [filter]
		# view.layer.addSublayer(blurLayer)
		# [superLayer addSublayer:blurLayer];

		collectionView.layer.addSublayer(blurLayer)
		# collectionView.setWantsLayer(true)
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
		comboview.layer.masksToBounds = false
		comboview.layer.cornerRadius = 8
		comboview.layer.shadowOffset = CGSizeMake(0, 2)
		comboview.layer.shadowRadius = 3
		comboview.layer.shadowOpacity = 0.3
		comboview.layer.shadowColor = UIColor.blackColor.CGColor
		personlabel.text = DEFAULT_DOCK[path.row]
		imageview.image = Event.image_from_title(personlabel.text)
		cell
	end

	def collectionView(cv, cellForItemAtIndexPath: path)
		cell = cv.dequeueReusableCellWithReuseIdentifier('Appt', forIndexPath:path)
		return setup_event_cell(cv, path, cell)
	end

end

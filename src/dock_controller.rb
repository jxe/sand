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

	def collectionView(cv, numberOfItemsInSection: section)
		4
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

		case path.row
		when 0
			imageview.image  = UIImage.imageNamed('sweet.png')
			personlabel.text = "add friend"
		when 1
			imageview.image  = UIImage.imageNamed('peace_and_quiet.jpg')
			personlabel.text = "quiet"
		when 2
			imageview.image  = UIImage.imageNamed('exercise.png')
			personlabel.text = "exercise"
		when 3
			imageview.image  = UIImage.imageNamed('creative.png')
			personlabel.text = "work"
		end
		cell
	end

	def collectionView(cv, cellForItemAtIndexPath: path)
		cell = cv.dequeueReusableCellWithReuseIdentifier('Appt', forIndexPath:path)
		return setup_event_cell(cv, path, cell)
	end

end

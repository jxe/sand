class DockItemCell < UICollectionViewCell
	attr_reader :dock_item
	attr_reader :system_item

	def imageview; contentView.viewWithTag(100); end
	def label; contentView.viewWithTag(102); end
	def comboview; contentView.viewWithTag(112); end

	def initWithCoder(c)
		super
		l = comboview.layer
		l.masksToBounds = false
		l.cornerRadius = 8
		l.shadowOffset = CGSizeMake(0, 2)
		l.shadowRadius = 1.8
		l.shadowOpacity = 0.7
		l.shadowColor = UIColor.blackColor.CGColor
		l.shadowPath = UIBezierPath.bezierPathWithRoundedRect(l.bounds, cornerRadius:8).CGPath
		self
	end


	def dock_item=(dock_item)
		@dock_item = dock_item
		@system_item = nil
		label.text = dock_item.title
		imageview.image = dock_item.uiimage
		label.color = UIColor.whiteColor
		label.shadowColor = UIColor.blackColor
		# comboview.backgroundColor = UIColor.blackColor
		label.backgroundColor = UIColor.colorWithHue(34, saturation:0.97, brightness:0.12, alpha:0.22)
		label.hidden = false
	end

	def system_item=(labeltext)
		@system_item = labeltext
		@dock_item = nil
		label.text = labeltext
		imageview.image = case labeltext
		when /appt/;   UIImage.imageNamed('plus.png')
		end

		label.hidden = true
		# comboview.backgroundColor = UIColor.whiteColor
	end

end

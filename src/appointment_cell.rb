class AppointmentCell < UICollectionViewCell
	def initWithCoder(c)
		super
		pl = contentView.viewWithTag(112).layer
		l = CALayer.layer
		l.contents = UIImage.imageNamed('blackrect.png').CGImage
		l.frame = CGRectMake(-6,-12,85,90)
		pl.insertSublayer(l, atIndex:0)
		self
	end

	def as_event(ev, cv, path)
		imageview = contentView.viewWithTag(100)
		timelabel = contentView.viewWithTag(101)
		personlabel = contentView.viewWithTag(102)

		timelabel.text   = ev.startDate.time_of_day_label
		imageview.image  = Event.image(ev){ cv.reloadItemsAtIndexPaths([path]) }
		personlabel.text = ev.title
	end

end

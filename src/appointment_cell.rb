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

	def imageview
		contentView.viewWithTag(100)
	end

	def comboview
		contentView.viewWithTag(112)
	end

	def as_event(ev, cv, path, ghosted)
		timelabel = contentView.viewWithTag(101)
		personlabel = contentView.viewWithTag(102)

		# timelabel.text   = ev.startDate.time_of_day_label.to_s.upcase.sub('_', ' ')
		timelabel.text   = ev.startDate.longer_time_of_day_label.to_s.upcase.sub('_', ' ')
		imageview.image  = Event.image(ev){ cv.reloadItemsAtIndexPaths([path]) }
		personlabel.text = ev.title

		ghosted ? ghost : unghost
	end

	def ghost
		comboview.alpha = 0.3
	end

	def unghost
		comboview.alpha = 1.0
	end

end

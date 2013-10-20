class AppointmentCell < UICollectionViewCell
	def initWithCoder(c)
		super
		pl = comboview.layer
		l = CALayer.layer
		l.contents = UIImage.imageNamed('blackrect.png').CGImage
		l.frame = CGRectMake(-6,-12,85,90)
		pl.insertSublayer(l, atIndex:0)
		self
	end

	def becomes_placeholder
		return if @is_placeholder
		bgimageview.hidden = false
		imageview.alpha = 1.0
		comboview.slide :right, 60, damping: 0.6, duration: 0.3
	end

	def recover_from_being_placeholder
		return if @is_placeholder
		comboview.slide :left, 60, damping: 0.6, duration: 0.3, completion:lambda{
			bgimageview.hidden = true
			imageview.alpha = 0.8
		}
	end


	def as_placeholder(t)
		self.hidden = false
		@is_placeholder = true
		comboview.hidden = true
		bgimageview.hidden = false
		self.time_of_day = t
	end

	def time_of_day= t
		timelabel.text = droptargetlabel.text = t.sub('_', ' ').upcase
	end

	def as_event(ev, cv, path, ghosted = nil)
		self.hidden = false
		@is_placeholder = false
		comboview.hidden = false
		bgimageview.hidden = true

		personlabel = contentView.viewWithTag(102)

		# timelabel.text   = ev.startDate.time_of_day_label.to_s.upcase.sub('_', ' ')
		self.time_of_day = ev.startDate.longer_time_of_day_label.to_s
		imageview.image  = Event.image(ev){ cv.reloadItemsAtIndexPaths([path]) }
		personlabel.text = ev.title

		ghosted ? ghost : unghost
	end

	def droptargetlabel
		contentView.viewWithTag(122)
	end

	def bgimageview
		contentView.viewWithTag(99)
	end

	def imageview
		contentView.viewWithTag(100)
	end

	def comboview
		contentView.viewWithTag(112)
	end

	def timelabel
		contentView.viewWithTag(101)
	end

	def timelabeltext=(text)
		timelabel.text = text
	end

	def ghost
		comboview.alpha = 0.3
	end

	def unghost
		comboview.alpha = 1.0
	end

end

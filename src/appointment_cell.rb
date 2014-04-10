class AppointmentCell < UICollectionViewCell
	attr_reader :event

	def initWithCoder(c)
		super
		pl = comboview.layer
		l = CALayer.layer
		l.contents = UIImage.imageNamed('blackrect.png').CGImage
		l.frame = CGRectMake(-6,-12,85,90)
		pl.insertSublayer(l, atIndex:0)

		v = UIView.alloc.initWithFrame(self.bounds)
		v.backgroundColor = UIColor.colorWithHue(0.60, saturation:0.05, brightness:1.0, alpha:1.0)
		l = v.layer

		l.masksToBounds = false
		l.cornerRadius = 4
		l.shadowOffset = CGSizeMake(0, 0)
		l.shadowRadius = 3.8
		l.shadowOpacity = 0.5
		l.shadowColor = UIColor.yellowColor.CGColor
		l.shadowPath = UIBezierPath.bezierPathWithRoundedRect(l.bounds, cornerRadius:4).CGPath

		self.selectedBackgroundView = v
		self
	end

	def setSelected(bool)
		super
		# cv = superview
		# if bool
		# 	MLPSpotlight.addSpotlightInView(cv, atPoint: cv.convertPoint(center, fromView: self))
		# else
		# 	MLPSpotlight.removeSpotlightsInView(cv)
		# end
	end

	def personlabel
		contentView.viewWithTag(102)
	end

	def update_timer_label seconds_remaining
		return kill_timer_label unless seconds_remaining
		@timer_label ||= begin
			label = UILabel.alloc.initWithFrame(CGRectMake(15, 32, bounds.width - 30, 20))
			label.font = UIFont.systemFontOfSize(13)
			label.backgroundColor =  UIColor.colorWithHue(0.0, saturation:0.00, brightness:0.0, alpha:0.5)
			label.textColor = UIColor.colorWithHue(0.0, saturation:0.5, brightness:1.0, alpha:1.0)
			label.layer.cornerRadius = 7
			label.layer.masksToBounds = true

			label.layer.shadowOpacity = 1.0;   
			label.layer.shadowRadius = 0.0;
			label.layer.shadowColor = UIColor.whiteColor.CGColor
			label.layer.shadowOffset = CGSizeMake(0.0, -1.0)

			label.textAlignment = NSTextAlignmentCenter
			contentView.addSubview(label)
			label
		end
		@timer_label.text = Time.at(seconds_remaining).utc.strftime("%M:%S")
		# if seconds_remaining > 100
		# 	@timer_label.text = "#{(seconds_remaining / 60).to_i}m";
		# else
		# 	@timer_label.text = "#{seconds_remaining}s"
		# end
	end


	def becomes_placeholder
		return if @is_placeholder
		bgimageview.hidden = droptargetlabel.hidden = false
		imageview.alpha = 1.0

		if Kernel.const_defined? "UIDynamicAnimator"
			comboview.slide :right, 60, damping: 0.6, duration: 0.3
		else
			comboview.slide :right, 60, duration: 0.3
		end
	end

	def recover_from_being_placeholder
		return if @is_placeholder

		if Kernel.const_defined? "UIDynamicAnimator"
			comboview.slide :left, 60, damping: 0.6, duration: 0.3 do
				bgimageview.hidden = droptargetlabel.hidden = true
				imageview.alpha = 0.8
			end
		else
			comboview.slide :left, 60, duration: 0.3 do
				bgimageview.hidden = droptargetlabel.hidden = true
				imageview.alpha = 0.8
			end
		end

	end


	def as_placeholder(placeholder)
		@event = nil
		@placeholder = placeholder
		self.hidden = false
		@is_placeholder = true
		comboview.hidden = true
		kill_timer_label
		bgimageview.hidden = droptargetlabel.hidden = false
		self.time_of_day = placeholder.label
		update_time_of_day
	end

	def time_of_day= t
		timelabel.text = droptargetlabel.text = t.sub('_', ' ').upcase
	end

	def color_for_hour hour
		hue = hour / 24.0
		UIColor.colorWithHue(hue, saturation:1.0, brightness:0.6, alpha:1.0)
	end

	def kill_timer_label
		@timer_label && @timer_label.removeFromSuperview
		@timer_label = nil
	end

	def as_event(ev, cv, path, ghosted = nil)
		@event = ev
		self.hidden = false
		@is_placeholder = false
		comboview.hidden = false
		kill_timer_label
		bgimageview.hidden = droptargetlabel.hidden = true

		# timelabel.text   = ev.startDate.time_of_day_label.to_s.upcase.sub('_', ' ')
		self.time_of_day = ev.startDate.longer_time_of_day_label.to_s

		if imageview.image  = ev.image{ cv.reloadItemsAtIndexPaths([path]) }
			imageview.backgroundColor = nil
			personlabel.backgroundColor = UIColor.colorWithHue(31.0/360.0, saturation:0.92, brightness:0.3, alpha:0.21)
		else
			imageview.backgroundColor = color_for_hour(ev.startDate.hour)
			personlabel.backgroundColor = nil
		end

		personlabel.text = ev.title || ev.person_name || "No name"

		ghosted ? ghost : unghost
		update_time_of_day
	end

	def startDate
		@event ? @event.startDate : @placeholder.startDate
	end

	def endDate
		@event ? @event.endDate : @placeholder.startDate+2.hours
	end

	def update_time_of_day(prev=nil)
		same = (prev == startDate)

		if Time.now < startDate
			# future
			timelabel.color = UIColor.colorWithHue(0.0333, saturation:0.19, brightness:0.60, alpha:0.90)
			comboview.alpha = 1.0
			timelabel.hidden = same
		elsif Time.now > endDate
			# past
			timelabel.color = UIColor.colorWithHue(0.0333, saturation:0.89, brightness:0.30, alpha:0.0)
			comboview.alpha = 0.3
			timelabel.hidden = same
		else
			timelabel.color = UIColor.colorWithHue(0.0333, saturation:0.94, brightness:0.70, alpha:0.90)
			comboview.alpha = 1.0
			timelabel.hidden = same
		end

		return startDate
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

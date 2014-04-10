class AddressBook::Person
	def autocompleteString
		composite_name
	end
end

class AffairView < UIView
	# def hitTest(point, withEvent: event)
	# 	result = super
	# 	NSLog "AffairView point: #{point.inspect}, event: #{event.inspect}; result: #{result.inspect}"
	# 	result
	# end
end

class AffairController < UIViewController	
	attr_reader :event

	def titleField;     view.viewWithTag(301); end
	def timeLabel;      view.viewWithTag(302); end
	def friendField;    view.viewWithTag(303); end
	def friendButton;   view.viewWithTag(304); end
	def suggsButton;    view.viewWithTag(305); end
	def xFriendButton;  view.viewWithTag(306); end
	def detailsView;    view.viewWithTag(307); end
	def locationButton; view.viewWithTag(308); end
	def urlButton;      view.viewWithTag(309); end


	def reviewButton;      view.viewWithTag(321); end
	def timerButton;      view.viewWithTag(322); end


	# def closeButton;    view.viewWithTag(310); end

	def self.instance
		@instance ||= begin
			s = UIStoryboard.storyboardWithName("MainStoryboard", bundle:nil)
			s.instantiateViewControllerWithIdentifier('Affair')
		end
	end

	def visible?
		@state != :hidden
	end

	def fully_visible?
		@state == :visible
	end

	def hide(cal)
		@state = :hidden
		view.frame = CGRectMake(0, cal.view.frame.size.height, cal.view.frame.size.width, cal.view.frame.size.height)
		view.endEditing(true)
		@superdelegate && @superdelegate.doneEditing
	end

	def animate_to_pixels_visible pixels
		parent_size = view.superview.bounds.size
		UIView.animateWithDuration 0.2, animations:lambda{
			f = UIApplication.sharedApplication.keyWindow.frame
			view.frame = CGRectMake(0, parent_size.height - pixels, parent_size.width, parent_size.height)
			view.autoresizingMask = UIViewAutoresizingFlexibleTopMargin
		}
	end

	def hide_animated(sender = nil)
		@state = :hidden
		view.endEditing(true)
		@superdelegate.doneEditing if @superdelegate
		animate_to_pixels_visible 0
	end

	def show_animated
		@state = :peeking
		animate_to_pixels_visible 180
	end

	def fully_show
		@state = :visible
		animate_to_pixels_visible view.frame.size.height
	end

	def self.instanceWithEventAndParent(*args)
		@instance.initWithEventAndParent(*args)
	end

	def viewDidLoad
		super

		timeLabel.delegate = self
		timeLabel.dataSource = self
		timeLabel.itemFont = UIFont.boldSystemFontOfSize(12.0)
		# timeLabel.peekInset = UIEdgeInsetsMake(0, 8, 0, 8)
		# timeLabel.rowIndent = 10.0
		timeLabel.showGlass = true


		timeLabel.gestureRecognizers[0].addTarget(self, action: :timer_menu)
		timerButton.addTarget(self, action: :show_timer_menu, forControlEvents: UIControlEventTouchUpInside)
		reviewButton.addTarget(self, action: :show_review_menu, forControlEvents: UIControlEventTouchUpInside)


		# set up actions
		# closeButton.addTarget(self, action: :hide_animated, forControlEvents: UIControlEventTouchUpInside)
		friendButton.addTarget(self, action: :go_friend, forControlEvents: UIControlEventTouchUpInside)
		urlButton.addTarget(self, action: :go_url, forControlEvents: UIControlEventTouchUpInside)
		locationButton.addTarget(self, action: :go_loc, forControlEvents: UIControlEventTouchUpInside)

		friendField.autoCompleteDataSource = self
		friendField.autoCompleteDelegate = self
		friendField.autoCompleteTableBackgroundColor = UIColor.whiteColor
		friendField.autoCompleteTableCellBackgroundColor = UIColor.whiteColor
		friendField.maximumNumberOfAutoCompleteRows = 6
		friendField.autoCompleteTableAppearsAsKeyboardAccessory = true

		friendField.delegate = self
		titleField.delegate = self
		detailsView.delegate = self
		detailsView.editable = true

		# add the swiping main menu gesture
		view.addGestureRecognizer(UIPanGestureRecognizer.alloc.initWithTarget(self, action: :swipeHandler))

		xFriendButton.addTarget(self, action: :xFriend, forControlEvents: UIControlEventTouchUpInside)

		l = view.layer
		l.masksToBounds = false
		# l.cornerRadius = 8
		l.shadowOffset = CGSizeMake(0, -2)
		l.shadowRadius = 0.5
		l.shadowOpacity = 0.4
		l.shadowColor = UIColor.blackColor.CGColor
		# l.shadowPath = UIBezierPath.bezierPathWithRoundedRect(l.bounds, cornerRadius:8).CGPath
	end

	def xFriend(sender=nil)
		event.person = nil
		Event.save(event)
		@superdelegate.redraw(event)
		layout
	end

	def show_timer_menu
		UI.menu ["Start a 5m timer", "Start a 10m timer", "Start a 20m timer", "Start a 30m timer"] do |chose|
			next unless chose =~ /(\d+(m|s))/
			dur = $1
			event.title = if event.title =~ /^\d+(m|s) (.*)/
				"#{dur} #{$2}"
			else
				"#{dur} #{event.title}"
			end

			Event.save(event)
			event.reset_timer
			event.start_stop_timer @superdelegate
			@superdelegate.redraw(event)
			hide_animated
		end
	end

	def show_review_menu
		UI.menu ["It was good", "Waste of time", "Reschedule", "Skip"] do |chose|
			# do some stuff
			@superdelegate.redraw(event)
			hide_animated
		end
	end

	def timer_menu gr = nil
		case gr.state
		when UIGestureRecognizerStateBegan
			show_timer_menu
		end
	end

	def swipeHandler(gr = nil)
		case gr.state
		when UIGestureRecognizerStateBegan
			@startY = view.frame.origin.y

		when UIGestureRecognizerStateChanged
			y = gr.translationInView(view.superview).y
			f = view.frame
			view.frame = CGRectMake(f.origin.x, @startY+y, f.size.width, f.size.height)

		when UIGestureRecognizerStateEnded
			vy = gr.velocityInView(view.superview).y
			return hide_animated if vy > 1000.0
			return fully_show if vy < -1000.0

			y = gr.locationInView(view.superview).y

			# puts "vy: #{vy}, y: #{y}"
			return hide_animated if y > 400
			return show_animated if y > 300
			return fully_show

			# snap to fully hidden, back to partly shown, or to fully shown
		end
	end

	def ab_people
		@ab_people ||= begin
			ab = AddressBook.address_book
			source = ABAddressBookCopyDefaultSource(ab);
			ppl = ABAddressBookCopyArrayOfAllPeopleInSourceWithSortOrdering(ab, source, KABPersonSortByLastName)
    		ABAddressBookRegisterExternalChangeCallback(ab, Proc.new {|_,_,_| @ab_people = nil }, nil)
			ppl.map{ |abp|  AddressBook::Person.new(ab, abp) }
		end
	end

	def autoCompleteTextField(tf, possibleCompletionsForString:str)
		ab_people.select{ |p| p.composite_name =~ /\b#{str}/i }
	end

	def textFieldShouldBeginEditing(tf)
		fully_show
		true
	end

	def textFieldDidEndEditing(tf)
		case tf
		when titleField
			event.title = tf.text
			event.reset_timer
			Event.save(event)
			@superdelegate.redraw(event)
			view.endEditing(true)
			layout
			show_animated if @state == :visible
		end
		true
	end

	def textViewShouldBeginEditing(tv)
		NSLog 'textViewShouldBeginEditing'
		return event.calendar.allowsContentModifications
	end

	def textViewDidEndEditing(tv)
		case tv
		when detailsView
			event.notes = tv.text
			Event.save(event)
		end
	end

	def textFieldShouldReturn(tf)
		textFieldDidEndEditing(tf)
	end

	def autoCompleteTextField(tf, didSelectAutoCompleteString:str, withAutoCompleteObject:obj, forRowAtIndexPath:path)
		event.person = obj
		# event.title = obj.composite_name if !event.title || event.title.length == 0
		Event.save(event)
		@superdelegate.redraw(event)
		layout
		show_animated if @state == :visible
	end

	def autoCompleteTextField(tf, shouldStyleAutoCompleteTableView:tv, forBorderStyle:bs)
		# tv.frame.width = 320.0
		return true
		# no op
	end

	def numberOfItemsInPickerView(pv)
		16
	end

	def pickerView(pv, titleForItem:i)
		return "" unless event
		offset = ((i - 8)*15).minutes
		date = event.startDate + offset
		date.strftime("%l:%M%P")[0..-2]
	end

	def pickerView(pv, didSelectItem:i)
		offset = ((i - 8)*15).minutes
		event.startDate += offset
		event.endDate += offset
		Event.save(event)
		@superdelegate.redraw(event)
		# timeLabel.reloadData
		# timeLabel.selectItemAtIndex(8, animated: false)
	end

	def layout
		if event.title =~ /^@/
			titleField.text = ""
		else
			titleField.text = event.title
		end

		timeLabel.reloadData
		timeLabel.selectItemAtIndex(8, animated: false)

		friend_name = event.person_name
		if friend_name
			friendButton.setTitle event.person_name, forState: UIControlStateNormal
			friendButton.hidden = false
			xFriendButton.hidden = false
			friendField.hidden = true
		else
			friendButton.hidden = true
			xFriendButton.hidden = true
			friendField.hidden = false
			friendField.text = ""
		end

		if event.URL or event.location
			suggsButton.hidden = true
			if event.URL
				urlButton.hidden = false
				case urlText = event.URL.absoluteString
				when /facebook.com/
					urlButton.setTitle "View on FB", forState: UIControlStateNormal
				else
					urlButton.setTitle urlText, forState: UIControlStateNormal
				end
			else
				urlButton.hidden = true
			end
			locationButton.setTitle event.location || "No Location", forState: UIControlStateNormal
		else
			urlButton.hidden = true
			locationButton.hidden = true
			setup_big_button
		end

		detailsView.text = event.notes || ""
		detailsView.editable = event.calendar.allowsContentModifications
	end


	def setup_big_button
		suggsButton.removeTarget(self, action: nil, forControlEvents: UIControlEventTouchUpInside)
		if event.title =~ /^\d+(m|h)\b/
			suggsButton.hidden = false
			if event.timer_running?
				suggsButton.setTitle "Stop timer", forState: UIControlStateNormal
			else
				suggsButton.setTitle "Start timer", forState: UIControlStateNormal
			end
			suggsButton.addTarget(self, action: :start_stop_timer, forControlEvents: UIControlEventTouchUpInside)
		elsif for_what = DockItem.suggestion_descriptor(event)
			suggsButton.hidden = false			
			suggsButton.setTitle for_what, forState: UIControlStateNormal
			suggsButton.addTarget(self, action: :go_suggs, forControlEvents: UIControlEventTouchUpInside)
		else
			suggsButton.hidden = true
		end
	end

	def go_friend sender = nil
		@superdelegate.display_friend_record event
	end

	def go_url sender = nil
		@superdelegate.go_to_url event.URL.absoluteString
	end

	def go_loc sender = nil
		loc = event.location.gsub(/ /, '+')
		if UIApplication.sharedApplication.canOpenURL(NSURL.URLWithString("comgooglemaps://"))
			NSLog "%@", "googlemaps: #{loc}"
			UIApplication.sharedApplication.openURL(NSURL.URLWithString("comgooglemaps://?q=#{loc}"))
		else
			NSLog "applemaps"
			UIApplication.sharedApplication.openURL(NSURL.URLWithString("http://maps.apple.com/?q=#{loc}"))
		end
	end

	def go_suggs sender = nil
		@superdelegate.display_suggestions event
	end

	def start_stop_timer sender = nil
		event.start_stop_timer @superdelegate
		layout
		hide_animated if event.timer_running?
	end

	def initWithEventAndParent(ev, eventStore, superdelegate)
		@event = ev
		@eventStore = eventStore
		@superdelegate = superdelegate
		layout
		self
	end
end


class AddressBook::Person
	def autocompleteString
		composite_name
	end
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
	def closeButton;    view.viewWithTag(310); end

	def self.instance
		@instance ||= begin
			s = UIStoryboard.storyboardWithName("MainStoryboard", bundle:nil)
			s.instantiateViewControllerWithIdentifier('Affair')
		end
	end

	def hide(cal)
		view.frame = CGRectMake(0, cal.view.frame.size.height, cal.view.frame.size.width, cal.view.frame.size.height)
		view.endEditing(true)
	end

	def hide_animated(sender = nil)
		view.endEditing(true)
		UIView.animateWithDuration 0.2, animations:lambda{
			f = UIApplication.sharedApplication.keyWindow.frame
			view.frame = CGRectMake(0, f.size.height, f.size.width, f.size.height)
		}
	end

	def show_animated
		UIView.animateWithDuration 0.2, animations:lambda{
			f = UIApplication.sharedApplication.keyWindow.frame
			dock_y = f.size.height - 180
			view.frame = CGRectMake(0, dock_y, f.size.width, f.size.height)
		}
	end

	def fully_show
		UIView.animateWithDuration 0.2, animations:lambda{
			f = UIApplication.sharedApplication.keyWindow.frame
			view.frame = CGRectMake(0, 0, f.size.width, f.size.height)
		}
	end

	def self.instanceWithEventAndParent(*args)
		@instance.initWithEventAndParent(*args)
	end

	def viewDidLoad
		# set up actions
		closeButton.addTarget(self, action: :hide_animated, forControlEvents: UIControlEventTouchUpInside)
		friendButton.addTarget(self, action: :go_friend, forControlEvents: UIControlEventTouchUpInside)
		suggsButton.addTarget(self, action: :go_suggs, forControlEvents: UIControlEventTouchUpInside)

		friendField.autoCompleteDataSource = self
		friendField.autoCompleteTableAppearsAsKeyboardAccessory = true
		friendField.autoCompleteDelegate = self

		friendField.delegate = self
		titleField.delegate = self

		# add the swiping main menu gesture
		view.addGestureRecognizer(UIPanGestureRecognizer.alloc.initWithTarget(self, action: :swipeHandler))

		# urlButton.addTarget(self, action: :suggestions, forControlEvents: UIControlEventTouchUpInside)
		xFriendButton.addTarget(self, action: :xFriend, forControlEvents: UIControlEventTouchUpInside)
		# locationButton.addTarget(self, action: :suggestions, forControlEvents: UIControlEventTouchUpInside)
	end

	def xFriend(sender=nil)
		event.person = nil
		Event.save(event)
		@superdelegate.redraw(event)
		layout
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

			puts "vy: #{vy}, y: #{y}"
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
			ppl.map{ |abp|  AddressBook::Person.new(ab, abp) }
		end
	end

	def autoCompleteTextField(tf, possibleCompletionsForString:str)
		ab_people.select{ |p| p.composite_name =~ /^#{str}/ }
		# return ["Foo", "Bar", "Baz"]
	end

	def textFieldShouldBeginEditing(tf)
		fully_show
		true
	end

	def textFieldDidEndEditing(tf)
		if tf == titleField
			event.title = tf.text
			Event.save(event)
			@superdelegate.redraw(event)
			view.endEditing(true)
			show_animated
		end
		true
	end

	def textFieldShouldReturn(tf)
		textFieldDidEndEditing(tf)
	end

	def autoCompleteTextField(tf, didSelectAutoCompleteString:str, withAutoCompleteObject:obj, forRowAtIndexPath:path)
		event.person = obj
		event.title = obj.composite_name if !event.title || event.title.length == 0
		Event.save(event)
		@superdelegate.redraw(event)
		layout
		show_animated
	end

	def autoCompleteTextField(tf, shouldStyleAutoCompleteTableView:tv, forBorderStyle:bs)
		tv.backgroundColor = UIColor.whiteColor
		return true
		# no op
	end

	def layout
		titleField.text = event.title
		timeLabel.text = event.startDate.strftime("%l:%M%P")

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

		urlText = event.URL ? event.URL.to_s : "No URL"
		locationButton.setTitle event.location || "No Location", forState: UIControlStateNormal
		urlButton.setTitle urlText, forState: UIControlStateNormal

		for_what = DockItem.suggestion_descriptor(event)
		suggsButton.setTitle for_what || "No suggestions", forState: UIControlStateNormal

		detailsView.text = event.notes || ""
	end

	def go_friend sender = nil
		@superdelegate.display_friend_record event
	end

	def go_suggs sender = nil
		@superdelegate.display_suggestions event
	end

	def initWithEventAndParent(ev, eventStore, superdelegate)
		@event = ev
		@eventStore = eventStore
		@superdelegate = superdelegate
		layout
		self
	end
end


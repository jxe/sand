class AppointmentViewController < EKEventViewController

	def one_button tv, v1
		v = UIView.alloc.initWithFrame(CGRectMake(0,0,tv.frame.width, 110))
		v.frame = CGRectMake(0,0,tv.frame.width, 60)
		Motion::Layout.new do |layout|
		  layout.view v
		  layout.subviews "suggs" => v1
		  layout.vertical "|-5-[suggs]-5-|"
		  layout.horizontal "|-10-[suggs]-10-|"
		end
		v
	end


	def two_buttons tv, v1, v2
		v = UIView.alloc.initWithFrame(CGRectMake(0,0,tv.frame.width, 110))
		Motion::Layout.new do |layout|
		  layout.view v
		  layout.subviews "friend" => v2, "suggs" => v1
		  layout.vertical "|-5-[friend]-5-[suggs(==friend)]-5-|"
		  layout.horizontal "|-10-[friend]-10-|"
		  layout.horizontal "|-10-[suggs]-10-|"
		end
		v
	end

	def makeHeaderView(tv)
		blueColor = UIColor.colorWithRed(0.0, green: 0.48, blue: 1.0, alpha:0.8)
		buttons = []

		if for_what = DockItem.suggestion_descriptor(event)
			suggs_button = UIButton.buttonWithType(UIButtonTypeCustom)
			suggs_button.backgroundColor = blueColor
			suggs_button.setTitle("#{for_what}", forState: UIControlStateNormal)
			suggs_button.addTarget(self, action: :suggestions, forControlEvents: UIControlEventTouchUpInside)
			buttons << suggs_button
		end

		if friend_name = event.person_name
			friend_button = UIButton.buttonWithType(UIButtonTypeCustom)
			friend_button.backgroundColor = blueColor
			friend_button.setTitle(friend_name, forState: UIControlStateNormal)
			friend_button.addTarget(self, action: :friend_record, forControlEvents: UIControlEventTouchUpInside)
			buttons << friend_button
		end

		# friend_button.setTitle("Link a friend", forState: UIControlStateNormal)
		# friend_button.addTarget(self, action: :link_friend, forControlEvents: UIControlEventTouchUpInside)


		return one_button tv, *buttons if buttons.length == 1
		return two_buttons tv, *buttons if buttons.length == 2
		return nil
	end

	def link_friend sender=nil
	end

	def friend_record sender = nil
		@superdelegate.display_friend_record event, navigationController
	end

	def suggestions sender = nil
		@superdelegate.display_suggestions event, navigationController
	end

	def initWithEventAndParent(ev, eventStore, superdelegate)
		self.event = ev
		self.allowsEditing = true
		self.delegate = self
		@eventStore = eventStore
		@superdelegate = superdelegate
		self
	end

	def viewWillAppear(animated = true)
		super
		tv = view.subviews.objectAtIndex(0)
		tv.tableHeaderView = makeHeaderView(tv)
	end

	def viewDidLoad
		super
		# l = UILabel.alloc.initWithFrame [[20,20],[280,44]]
	    # l.text = "Check this out"

	    editItem = UIBarButtonItem.alloc.initWithBarButtonSystemItem(UIBarButtonSystemItemEdit, target:self, action: :editCalEvent)
	    navigationItem.rightBarButtonItem = editItem
	end

	def editCalEvent
	    editController = EKEventEditViewController.alloc.init
    	editController.event = event
    	editController.eventStore = @eventStore
    	editController.editViewDelegate = self
    	presentModalViewController(editController, animated:true)
	end

	def eventViewController(c, didCompleteWithAction: action)
		case action
		when EKEventViewActionDeleted
			@superdelegate.animate_rm(event)
		else
			@superdelegate.was_modified(event) if @event_was_modified
		end
		dismissViewControllerAnimated true, completion:nil
	end

	def eventEditViewController(c, didCompleteWithAction: action)
		case action
		when EKEventEditViewActionSaved
			@event_was_modified = true
			dismissViewControllerAnimated true, completion:nil
		when EKEventEditViewActionDeleted
			dismissViewControllerAnimated false, completion:lambda{
				dismissViewControllerAnimated true, completion:nil
				@superdelegate.animate_rm(event)
			}
		else
			dismissViewControllerAnimated true, completion:nil
		end
	end
end

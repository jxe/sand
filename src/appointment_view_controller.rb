class AppointmentViewController < EKEventViewController

	def makeHeaderView(tv)
		v = UIView.alloc.initWithFrame(CGRectMake(0,0,tv.frame.width, 80))
		friend_name = @superdelegate.friend_name(event)

		suggs_button = UIButton.buttonWithType(UIButtonTypeSystem)
		suggs_button.setTitle("Suggestions for #{event.title}", forState: UIControlStateNormal)
		suggs_button.addTarget(self, action: :suggestions, forControlEvents: UIControlEventTouchUpInside)

		if !friend_name
			v.frame = CGRectMake(0,0,tv.frame.width, 40)

			Motion::Layout.new do |layout|
			  layout.view v
			  layout.subviews "suggs" => suggs_button
			  layout.vertical "|-15-[suggs]-15-|"
			  layout.horizontal "|-10-[suggs]-10-|"
			end

			return v
		end

		friend_button = UIButton.buttonWithType(UIButtonTypeSystem)
		if friend_name
			friend_button.setTitle(friend_name, forState: UIControlStateNormal)
			friend_button.addTarget(self, action: :friend_record, forControlEvents: UIControlEventTouchUpInside)
		else
			friend_button.setTitle("Link a friend", forState: UIControlStateNormal)
			friend_button.addTarget(self, action: :link_friend, forControlEvents: UIControlEventTouchUpInside)
		end

		Motion::Layout.new do |layout|
		  layout.view v
		  layout.subviews "friend" => friend_button, "suggs" => suggs_button
		  layout.vertical "|-15-[friend]-10-[suggs(==friend)]-15-|"
		  layout.horizontal "|-10-[friend]-10-|"
		  layout.horizontal "|-10-[suggs]-10-|"
		end

		v
	end

	def link_friend sender=nil
	end

	def friend_record sender = nil
		@superdelegate.display_friend_record event, navigationController
	end

	def suggestions sender = nil
		@superdelegate.display_suggestions event, navigationController
	end

	def initWithEventAndParent(ev, superdelegate)
		self.event = ev
		self.allowsEditing = true
		self.delegate = self
		@superdelegate = superdelegate
		self
	end

	def viewWillAppear(animated = true)
		super
	end

	def viewDidLoad
		super
		# l = UILabel.alloc.initWithFrame [[20,20],[280,44]]
	 #    l.text = "Check this out"
		tv = view.subviews.objectAtIndex(0)
		tv.tableHeaderView = makeHeaderView(tv)
	end

	def eventViewController(c, didCompleteWithAction: action)
		dismissViewControllerAnimated true, completion:nil
	end

	def eventEditViewController(c, didCompleteWithAction: action)
		dismissViewControllerAnimated true, completion:nil
	end
end

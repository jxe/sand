class UpcomingController < UICollectionViewController



	############
	# lifecycle

	def viewDidLoad
		super
		load_events
		collectionView.delegate = self
		collectionView.dataSource = self
		collectionView.gestureRecognizers[2].addTarget(self, action: :longPress)
	end

	def viewWillAppear(animated)
		super
		@ekobserver = App.notification_center.observe(EKEventStoreChangedNotification){ |x| reload }
	end

	def viewWillDisappear(animated)
		super
		App.notification_center.unobserve @ekobserver if @ekobserver
	end

	def fetch_events start_date, end_date
		@event_store ||= EKEventStore.alloc.init
	 	@event_store.requestAccessToEntityType(EKEntityTypeEvent, completion: nil);
	 	p = @event_store.predicateForEventsWithStartDate(start_date, endDate: end_date, calendars: nil)
		@event_store.eventsMatchingPredicate(p)
	end

	def load_events
		events = fetch_events(Time.now - 2.hours, Time.now + 9.days) || []
		puts "#{events.length} events from cal"
		@sections = {}
		events.each do |ev|
			next if ev.allDay? or ev.availability == EKEventAvailabilityFree
			next if ev.endDate.timeIntervalSinceDate(ev.startDate) > 18.hours
			next if Event.is_hidden?(ev.eventIdentifier)
			morning = ev.startDate.start_of_day
			section = @sections[morning] ||= []
			section << ev unless section.detect{ |existing| existing.title == ev.title }
		end
		too_early = @sections.keys.select{ |d| d.timeIntervalSinceNow < -20*60*60 }
		too_early.each{ |d| @sections.delete d }
		@section_order = @sections.keys.sort
	end

	def reload
  		load_events
  		collectionView.reloadData
	end


	############
	# actions

	def composeAction
		@event_store ||= EKEventStore.alloc.init
		c = EKEventEditViewController.alloc.init.tap do |c|
			c.eventStore = @event_store
		    c.editViewDelegate = self
		end
    	presentViewController c, animated: true, completion: nil
	end

	def eventEditViewController(c, didCompleteWithAction: action)
		dismissViewControllerAnimated true, completion: nil
	end

	def collectionView(cv, didSelectItemAtIndexPath:path)
		s = @sections[@section_order[path.section]]
		ev = s[path.row]
		puts "looked up event for eventViewController"
		return false unless ev
		puts "pushing eventViewController"
		eventViewController = EKEventViewController.alloc.init
		eventViewController.event = ev
		eventViewController.allowsEditing = true
		navigationController.pushViewController(eventViewController, animated: true)
	end

	def longPress
		gr = collectionView.gestureRecognizers[2]
		return unless gr.state == UIGestureRecognizerStateBegan

		p = gr.locationInView(collectionView)
		path = collectionView.indexPathForItemAtPoint(p)
    	ev = event_at_index_path(path)
    	return unless ev

		UIActionSheet.alert 'Hmm', buttons: ['Cancel', 'Link friend', 'Hide'],
		  cancel: proc { "hi" },
		  success: proc { |pressed|
		  	case pressed
		  	when 'Hide';
		  		Event.hide(ev.eventIdentifier)
		  		reload
		  	when 'Link friend';
		  		AddressBook.pick do |person|
		  			return unless person
		  			Event.assign(ev.eventIdentifier, person)
		  			collectionView.reloadItemsAtIndexPaths([path])
		  		end
		  	end
	  	  }
	end


	##############
	# data source

	def numberOfSectionsInCollectionView(cv)
		@section_order.length
	end

	def collectionView(cv, numberOfItemsInSection: section)
		s = @section_order[section]
		# return 0 if s.timeIntervalSinceNow < -120*60
		@sections[s].length || 0
	end

	def event_at_index_path(path)
		@sections[@section_order[path.section]][path.row]
	end

	def collectionView(cv, cellForItemAtIndexPath: path)
		ev = event_at_index_path path
		return nil unless ev
		cell = cv.dequeueReusableCellWithReuseIdentifier('Appt', forIndexPath:path)
		imageview = cell.contentView.viewWithTag(100)
		timelabel = cell.contentView.viewWithTag(101)
		personlabel = cell.contentView.viewWithTag(102)

		# configure cell
		timelabel.text   = time_of_day(ev.startDate)
		imageview.image  = Event.image(ev){ cv.reloadItemsAtIndexPaths([path]) }
		personlabel.text = if ev.organizer && !ev.organizer.isCurrentUser
			ev.organizer.name.split[0]
		else
			ev.title
		end

		cell
	end

	def collectionView(cv, viewForSupplementaryElementOfKind:kind, atIndexPath:path)
		return unless kind == UICollectionElementKindSectionHeader
		view = cv.dequeueReusableSupplementaryViewOfKind(kind, withReuseIdentifier:'Section', forIndexPath:path)
		section_date = @section_order[path.section]
		view.subviews[0].text = day_of_week(section_date)
		view
	end


	###############################
	# image, time, and title logic

	def day_of_week t
		return "TODAY" if t.today?
		return "TOMORROW" if t.same_day?(NSDate.tomorrow)
		return t.strftime "%A     (%m/%d)"
	end

	def time_of_day t
		return 'DAWN' if t.hour < 8
		return 'BFST' if t.hour < 10
		return 'MORN'  if t.hour < 12
		return 'LUNCH' if t.hour < 14
		return 'AFT'   if t.hour < 16
		return 'HPY HR' if t.hour < 18
		return 'DIN'   if t.hour < 21
		return 'LATE'

		# .string_with_format("h:mma")
	end
end

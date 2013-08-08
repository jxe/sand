class UpcomingController < UICollectionViewController


	################
	# calendar model

	def timeframe
		dates = timeframe_dates
		[dates[0], dates[-1] + 24.hours]
	end

	def timeframe_dates
		today = Time.today
		(0..14).map{ |n| today.delta(days: n).start_of_day }
	end

	def load_events
		@events_by_day = {}
		legit_events(timeframe).each do |ev|
			morning = ev.startDate.start_of_day
			section = @events_by_day[morning] ||= []
			section << ev unless section.detect{ |existing| existing.title == ev.title }
		end
	end

	def sections
		@editing ? timeframe_dates : @events_by_day.keys.sort
	end

	def item_count_for_section n
		date = sections[n]
		events = @events_by_day[date] || []
		@editing ? events.length + 1 : events.length
	end

	def unscheduled_sections
		timeframe_dates - @events_by_day.keys
	end

	def thing_at_index_path p
		date = sections[p.section]
		row = @events_by_day[date] || []
		ev = row[p.row]
		# puts "#{p.section.inspect} #{p.row.inspect}: #{ev.inspect}"
		return :event, ev if ev
		return :plus, date
	end



	################
	# transitions

	def batch_updates &foo
		collectionView.performBatchUpdates(proc{ foo.call(collectionView) }, completion:nil)
	end

	def only_when_editing
		rm_sections = []
		plus_indexes = []
		timeframe_dates.each_with_index do |date, i|
			if events = @events_by_day[date]
				plus_indexes << [i, events.length]
			else
				rm_sections << i
			end
		end
		# puts "insertSections: #{new_sections.inspect}"
		# puts "insertItemsAtIndexPaths: #{plus_indexes.inspect}"
		return [plus_indexes, rm_sections]
	end

	def start_editing
		@editing = true
		plus_indexes, new_sections = *only_when_editing
		batch_updates do |cv|
			cv.insertSections(new_sections.nsindexset)
			cv.insertItemsAtIndexPaths(plus_indexes.map(&:nsindexpath))
		end
	end

	def stop_editing
		@editing = false
		plus_indexes, rm_sections = *only_when_editing
		batch_updates do |cv|
			cv.deleteItemsAtIndexPaths(plus_indexes.map(&:nsindexpath))
			cv.deleteSections(rm_sections.nsindexset)
		end
	end


	############
	# lifecycle

	def legit_events(tf)
		events = fetch_events(*tf) || []
		puts "#{events.length} events from cal"
		events.select do |ev|
			next if ev.allDay? or ev.availability == EKEventAvailabilityFree
			next if ev.endDate.timeIntervalSinceDate(ev.startDate) > 18.hours
			next if ev.startDate.timeIntervalSinceNow < -20.hours
			next if Event.is_hidden?(ev.eventIdentifier)
			true
		end
	end

	def viewDidLoad
		super
		load_events
		collectionView.delegate = self
		collectionView.dataSource = self
		collectionView.gestureRecognizers[2].addTarget(self, action: :longPress)
		# navigationController.navigationBar.configureFlatNavigationBarWithColor(UIColor.carrotColor)
		# UIColor.midnightBlueColor
		# UIBarButtonItem.configureFlatButtonsWithColor(UIColor.peterRiverColor, 
  #                             highlightedColor: UIColor.belizeHoleColor,
  #                                 cornerRadius: 3)
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

	def reload
  		load_events
  		collectionView.reloadData
	end


	############
	# actions

	def composeAction
		if @editing
			stop_editing
			self.navigationItem.rightBarButtonItem = UIBarButtonItem.alloc.initWithBarButtonSystemItem(UIBarButtonSystemItemEdit, target: self, action: :composeAction)
		else
			start_editing
			self.navigationItem.rightBarButtonItem = UIBarButtonItem.alloc.initWithBarButtonSystemItem(UIBarButtonSystemItemDone, target: self, action: :composeAction)
		end
	end

	def eventEditViewController(c, didCompleteWithAction: action)
		dismissViewControllerAnimated true, completion: nil
	end

	def compose_event start_time, person
		@event_store ||= EKEventStore.alloc.init
		ev = EKEvent.eventWithEventStore(@event_store)
		ev.startDate = start_time
		ev.endDate = start_time + 2.hours
		c = EKEventEditViewController.alloc.init.tap do |c|
			c.eventStore = @event_store
			c.event = ev
		    c.editViewDelegate = self
		end
    	presentViewController c, animated: true, completion: nil
	end

	def compose_event_with_picked_friend start_time
  		AddressBook.pick do |person|
  			return compose_event start_time unless person
			@event_store ||= EKEventStore.alloc.init
			ev = EKEvent.eventWithEventStore(@event_store)
			ev.startDate = start_time
			ev.endDate = start_time + 2.hours
			ev.setCalendar(@event_store.defaultCalendarForNewEvents)
  			error = Pointer.new('@')
  			@event_store.saveEvent(ev, span:EKSpanThisEvent, commit:true, error:error)
  			Event.assign(ev.eventIdentifier, person)
  		end
	end


	def collectionView(cv, didSelectItemAtIndexPath:path)
		kind, thing = thing_at_index_path path
		case kind
		when :event
			return false unless ev = thing
			eventViewController = EKEventViewController.alloc.init
			eventViewController.event = ev
			eventViewController.allowsEditing = true
			navigationController.pushViewController(eventViewController, animated: true)
		when :plus
			date = thing
			UIActionSheet.alert nil, buttons: ['Cancel', 'Lunch', 'Dinner'],
			  cancel: proc { "hi" },
			  success: proc { |pressed|
			  	case pressed
			  	when 'Lunch';
			  		compose_event_with_picked_friend(date + 12.hours)
			  		# compose_event date + 12.hours
			  	when 'Dinner';
			  		compose_event_with_picked_friend(date + 18.hours)
			  		# compose_event date + 18.hours
			  	end
		  	  }
		end
	end

	def longPress
		gr = collectionView.gestureRecognizers[2]
		return unless gr.state == UIGestureRecognizerStateBegan

		p = gr.locationInView(collectionView)
		path = collectionView.indexPathForItemAtPoint(p)
    	kind, ev = thing_at_index_path(path)
    	return unless kind == :event and ev

		UIActionSheet.alert nil, buttons: ['Cancel', 'Link friend', 'Hide'],
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
		sections.length
	end

	def collectionView(cv, numberOfItemsInSection: section)
		item_count_for_section section
	end

	def setup_event_cell(cell, ev)
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

	def collectionView(cv, cellForItemAtIndexPath: path)
		kind, ev = thing_at_index_path path
		case kind
		when :event
			return nil unless ev
			cell = cv.dequeueReusableCellWithReuseIdentifier('Appt', forIndexPath:path)
			return setup_event_cell(cell, ev)

		when :plus
			return cv.dequeueReusableCellWithReuseIdentifier('Plus', forIndexPath:path)
		end
	end

	def collectionView(cv, viewForSupplementaryElementOfKind:kind, atIndexPath:path)
		return unless kind == UICollectionElementKindSectionHeader
		view = cv.dequeueReusableSupplementaryViewOfKind(kind, withReuseIdentifier:'Section', forIndexPath:path)
		section_date = sections[path.section]
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
		return 'DINNER' if t.hour < 21
		return 'LATE'

		# .string_with_format("h:mma")
	end
end

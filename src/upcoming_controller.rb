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
			section << ev unless section.detect{ |existing| existing.title == ev.title and existing.startDate == ev.startDate }
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
		return [plus_indexes, rm_sections]
	end

	def toggle_editing
		@editing = !@editing
		plus_indexes, extra_sections = *only_when_editing
		batch_updates do |cv|
			if @editing
				cv.insertSections(extra_sections.nsindexset)
				cv.insertItemsAtIndexPaths(plus_indexes.map(&:nsindexpath))
			else
				cv.deleteItemsAtIndexPaths(plus_indexes.map(&:nsindexpath))
				cv.deleteSections(extra_sections.nsindexset)
			end
		end
	end



	################
	# calendar model

	def add_event start_time, friend, title = nil
		return AddressBook.pick do |person|
			add_event(start_time, person, title)
		end if friend == :pick

		@event_store ||= EKEventStore.alloc.init
		ev = EKEvent.eventWithEventStore(@event_store)
		ev.startDate = start_time
		ev.endDate = start_time + 2.hours
		ev.title = title || (friend && "with #{friend.composite_name}") || "New event"
		ev.setCalendar(@event_store.defaultCalendarForNewEvents)
		error = Pointer.new('@')
		@event_store.saveEvent(ev, span:EKSpanThisEvent, commit:true, error:error)
		Event.assign(ev.eventIdentifier, friend) if friend
	end

	def fetch_events start_date, end_date
		@event_store ||= EKEventStore.alloc.init
	 	@event_store.requestAccessToEntityType(EKEntityTypeEvent, completion: nil);
	 	p = @event_store.predicateForEventsWithStartDate(start_date, endDate: end_date, calendars: nil)
		@event_store.eventsMatchingPredicate(p)
	end

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

	def day_of_week t
		return "TODAY" if t.today?
		return "TOMORROW" if t.same_day?(NSDate.tomorrow)
		return t.strftime("%A     (%m/%d)").upcase
	end

	HOUR_RANGES = {
		predawn: 0...5,
		dawn: 5...8,
		bfst: 8...10,
		morn: 10...12,
		lunch: 12...14,
		aft: 14...16,
		hpy_hr: 16...18,
		dinner: 18...21,
		night: 21...24
	}

	KEY_HOUR_RANGES = %w{ bfst morn lunch aft hpy_hr dinner night }

	def time_of_day t
		HOUR_RANGES.each do |k,v|
			return k if v.include? t.hour
		end
	end

	# def time_of_day t
	# 	return 'DAWN' if t.hour < 8
	# 	return 'BFST' if t.hour < 10
	# 	return 'MORN'  if t.hour < 12
	# 	return 'LUNCH' if t.hour < 14
	# 	return 'AFT'   if t.hour < 16
	# 	return 'HPY HR' if t.hour < 18
	# 	return 'DINNER' if t.hour < 21
	# 	return 'LATE'
	# 	# .string_with_format("h:mma")
	# end


	############
	# lifecycle

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

	def reload
  		load_events
  		collectionView.reloadData
	end



	############
	# actions

	def choose_paint
		# simple risky brainy active sweet outdoor quiet creative rowdy
		menu2000 %w{ exercise creative sweet } do |paint|
			puts "...got paint #{paint.inspect}"
			paint_with paint if paint
		end
	end

	def done_action
		paint_with nil
		toggle_editing if @editing
		navigationItem.rightBarButtonItem = UIBarButtonItem.alloc.initWithBarButtonSystemItem(UIBarButtonSystemItemEdit, target: self, action: :edit_action)
	end

	def edit_action
		toggle_editing unless @editing
		navigationItem.rightBarButtonItem = UIBarButtonItem.alloc.initWithBarButtonSystemItem(UIBarButtonSystemItemDone, target: self, action: :done_action)
	end

	def options_menu_for_event ev
    	menu2000 ['Link friend', 'Hide'] do |pressed|
		  	case pressed
		  	when 'Hide';
		  		Event.hide(ev.eventIdentifier)
		  		reload
		  	when 'Link friend';
		  		AddressBook.pick do |person|
		  			next unless person
		  			Event.assign(ev.eventIdentifier, person)
		  			collectionView.reloadItemsAtIndexPaths([path])
		  		end
		  	end
    	end
	end



	############
	# controller model stuff

	def paint_with paint
		return unless @paint = paint
		puts "got paint #{paint.inspect}"
		navigationController.navigationBar.prompt = paint && "Painting with #{paint}"
		edit_action
	end

	def collectionView(cv, didSelectItemAtIndexPath:path)
		kind, thing = thing_at_index_path path
		case kind
		when :event
			return false unless ev = thing
			return options_menu_for_event ev if @editing
			eventViewController = EKEventViewController.alloc.init
			eventViewController.event = ev
			eventViewController.allowsEditing = true
			navigationController.pushViewController(eventViewController, animated: true)
		when :plus
			date = thing
			menu2000 KEY_HOUR_RANGES do |pressed|
				range = HOUR_RANGES[pressed.to_sym]
				next unless range
				start_time = date + range.begin.hours
		  		add_event(start_time, @paint ? nil : :pick, @paint)
				paint_with nil if @paint
				done_action
		    end
		end
	end

	def longPress
		gr = collectionView.gestureRecognizers[2]
		return unless gr.state == UIGestureRecognizerStateBegan

		p = gr.locationInView(collectionView)
		path = collectionView.indexPathForItemAtPoint(p)
    	kind, ev = thing_at_index_path(path)
    	return unless kind == :event and ev
    	options_menu_for_event ev
	end


	##############
	# misc controller wireups

	def eventEditViewController(c, didCompleteWithAction: action)
		dismissViewControllerAnimated true, completion: nil
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



	##############
	# improve uikit

	def menu2000 options, &cb
		puts "menu2000 called"
		UIActionSheet.alert nil, buttons: ['Cancel', nil, *options], success: proc{ |thing|
			puts "Got: #{thing.inspect}"
			cb.call(thing) unless thing == 'Cancel' or thing == :Cancel
		}, cancel: proc{
			puts "cancel..."
		}
	end

	def batch_updates &foo
		collectionView.performBatchUpdates(proc{ foo.call(collectionView) }, completion:nil)
	end

end

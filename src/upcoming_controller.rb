LIVE = []

class Paints
	def self.menu_options
		['Add friend date', 'Add some exercise', 'Add creative work', 'Add something sweet']
	end

	def self.from_menu_option o
		word = o.split[-1]
		return "creative" if word == 'work'
		return word
	end

	def self.prompt word
		{
			'exercise' => 'Add exercise', 
			'creative' => 'Add creative',
			'sweet'    => 'Add something sweet'
		}[word]
	end
end

class EventCell < UICollectionReusableView
	def initWithCoder(c)
		super
		gradient = CAGradientLayer.layer
		gradient.frame = bounds
		gradient.endPoint = [0.5, 0.4]
		startColor = UIColor.colorWithHue(0.12, saturation:0.12, brightness:0.88, alpha:0.4)
		sandClear = UIColor.colorWithHue(0.12, saturation:0.12, brightness:1.0, alpha:0.01)
		# UIColor.colorWithWhite(0.9, alpha: 1.0)
 		gradient.colors = [startColor.CGColor, sandClear.CGColor]
 		layer.insertSublayer(gradient, atIndex:0)
 		self
	end
end

class UpcomingController < UICollectionViewController


	#########################
	# calendar display model

	def timeframe
		dates = timeframe_dates
		[dates[0], dates[-1] + 24.hours]
	end

	def timeframe_dates
		today = Time.today
		(0..14).map{ |n| today.delta(days: n).start_of_day }
	end

	def load_events
		puts "loading events"
		@events_by_day = {}
		Event.legit_events(timeframe).each do |ev|
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

	def reload_plusses
		plus_indexes, extra_sections = *only_when_editing
		collectionView.reloadItemsAtIndexPaths(plus_indexes.map(&:nsindexpath))
	end

	def toggle_editing
		puts "toggle_editing called"
		plus_indexes, extra_sections = *only_when_editing
		batch_updates do |cv|
			@editing = !@editing
			puts "running batch updates"
			puts "#{@editing.inspect}: #{extra_sections.inspect}"
			if @editing
				puts "inserting"
				cv.insertSections(extra_sections.nsindexset)
				cv.insertItemsAtIndexPaths(plus_indexes.map(&:nsindexpath))
			else
				puts "deleting"
				cv.deleteItemsAtIndexPaths(plus_indexes.map(&:nsindexpath))
				cv.deleteSections(extra_sections.nsindexset)
			end
		end
		puts "updates completed"
	end




	############
	# lifecycle

	def viewDidLoad
		super
		puts "viewDidLoad"
		load_events
		collectionView.delegate = self
		collectionView.dataSource = self
		collectionView.gestureRecognizers[2].addTarget(self, action: :longPress)
		# self.automaticallyAdjustsScrollViewInsets = false
		# collectionView.contentInset = UIEdgeInsetsMake(94,0,0,0)

		navigationController.navigationBar.barTintColor = UIColor.colorWithHue(0.12, saturation:0.42, brightness:0.94, alpha:0.6)

		# gradient = CAGradientLayer.layer
		# gradient.frame = navigationController.navigationBar.bounds
		# sand = UIColor.colorWithHue(0.12, saturation:0.3, brightness:0.80, alpha:0.4)
		# sandClear = UIColor.colorWithHue(0.12, saturation:0.00, brightness:1.0, alpha:0.01)
		# UIColor.colorWithWhite(0.9, alpha: 1.0)
 		# gradient.colors = [sand.CGColor, sand.CGColor]
 		# navigationController.navigationBar.layer.insertSublayer(gradient, atIndex:0)

		# navigationController.navigationBar.setBackgroundImage(UIImage.imageNamed("sandbar2.png"), forBarMetrics: UIBarMetricsDefault)
		navigationController.navigationBar.setTitleVerticalPositionAdjustment(4, forBarMetrics:UIBarMetricsDefault)


		view.addGestureRecognizer(UIPanGestureRecognizer.alloc.initWithTarget(self, action: :swipeHandler))
	end

	def swipeHandler sender = nil
		sideMenu.showFromPanGesture(sender)
	end


	def viewWillAppear(animated)
		super
		LIVE[0] = self
		@ekobserver = App.notification_center.observe(EKEventStoreChangedNotification){ |x| reload }
		navigationController.setToolbarHidden(true,animated:true)
	end

	def viewWillDisappear(animated)
		super
		App.notification_center.unobserve @ekobserver if @ekobserver
	end

	def reload
		puts "reloading events"
  		load_events
  		puts "updatign collectionview"
  		collectionView.reloadData
		@view_editing = @editing
		puts "done reloading"
	end



	############
	# actions

	def menu_action
		self.sideMenu.show
	end

	def add_event start_time, friend, title = nil
		puts "add_event: #{friend.inspect} #{title.inspect}"

		return AddressBook.pick do |person|
			add_event(start_time, person, title)
		end if friend == :pick

		puts "add_event: #{friend.inspect} #{title.inspect}"
		Event.add_event(start_time, friend, title)
	end

	def choose_paint
		# simple risky brainy active sweet outdoor quiet creative rowdy
		canceled = proc{ @paint = nil; done_action }
		menu Paints.menu_options, canceled do |picked|
			case picked
			when 'Add friend date';    paint_with nil; edit_action
			else paint_with Paints.from_menu_option(picked)
			end
		end
	end

	def done_action
		# paint_with nil
		toggle_editing if @editing
		# navigationItem.rightBarButtonItem = UIBarButtonItem.alloc.initWithBarButtonSystemItem(UIBarButtonSystemItemEdit, target: self, action: :edit_action)
		navigationItem.setLeftBarButtonItem(nil)
		navigationItem.setLeftBarButtonItem(UIBarButtonItem.alloc.initWithBarButtonSystemItem(UIBarButtonSystemItemPause, target:self, action: :menu_action))
	end

	def edit_action
		toggle_editing unless @editing
    	navigationItem.setLeftBarButtonItem(UIBarButtonItem.alloc.initWithBarButtonSystemItem(UIBarButtonSystemItemCancel, target:self, action: :done_action))
		# navigationItem.rightBarButtonItem = UIBarButtonItem.alloc.initWithBarButtonSystemItem(UIBarButtonSystemItemDone, target: self, action: :done_action)
	end

	def options_menu_for_event ev, path
		options = ['View']

		if Event.unlinked?(ev)
			options << 'Add friend' 
		else
			options << 'Unlink friend'
		end

		if ev.calendar.allowsContentModifications
			options << 'Reschedule' << 'Delete'
		else
			options << 'Hide'
		end

		menu options do |x|
			case x
			when 'View'
				view_event ev
			when 'Add friend'
		  		AddressBook.pick do |person|
		  			next unless person
		  			Event.assign(ev.eventIdentifier, person)
		  			collectionView.reloadItemsAtIndexPaths([path])
		  		end
			when 'Unlink friend'
			when 'Reschedule'
			when 'Delete'
		  		Event.delete!(ev)

			when 'Hide'
		  		Event.hide(ev.eventIdentifier)
		  		reload
			end
		end
	end

	def paint_with paint
		@paint = paint
		# navigationController.navigationBar.prompt = paint && "Painting with #{paint}"
		if paint and not @editing
			edit_action
		elsif @editing
			# change pluses
			reload_plusses
		end
	end

	def add_event_on_date date
		paint_was = @paint
		menu %w{ bfst morn lunch aft hpy_hr dinner night } do |pressed|
			next unless range = NSDate::HOUR_RANGES[pressed.to_sym]
			@editing = nil
			navigationItem.setLeftBarButtonItem(nil)
			start_time = date + range.begin.hours
			# puts "paint: #{@paint.inspect}"
			# puts "add_event_on_date: #{start_time.inspect} #{paint_was.inspect}"
			# puts "foo #{paint_was.inspect}"
			if paint_was
				@paint = nil
				Event.add_event(start_time, nil, paint_was)
			else
				AddressBook.pick do |person|
					Event.add_event(start_time, person)
				end
			end
	  		puts "added"
	    end
	end

	def view_event ev
		return false unless ev
		eventViewController = EKEventViewController.alloc.init
		eventViewController.event = ev
		eventViewController.allowsEditing = true
		eventViewController.delegate = self
		navigationController.pushViewController(eventViewController, animated: true)
	end


	##############
	# wiring

	def collectionView(cv, didSelectItemAtIndexPath:path)
		kind, thing = thing_at_index_path path
		case kind
		when :event
			if Event.unlinked_painted?(thing) or @editing
				options_menu_for_event(thing, path)
			else
				view_event(thing)
			end
			
		when :plus
			add_event_on_date thing
		end
	end

	def longPress
		gr = collectionView.gestureRecognizers[2]
		return unless gr.state == UIGestureRecognizerStateBegan

		p = gr.locationInView(collectionView)
		path = collectionView.indexPathForItemAtPoint(p)
		return unless path
		if path.section and not path.row
			return add_event_on_date sections[path.section]
		end
    	kind, ev = thing_at_index_path(path)
    	return unless kind == :event and ev
    	options_menu_for_event ev, path
	end

	def eventViewController(c, didCompleteWithAction: action)
		dismissViewControllerAnimated true
		# navigationController.setToolbarHidden(true,animated:true)
	end


	##############
	# data source

	def numberOfSectionsInCollectionView(cv)
		sections.length
	end

	def collectionView(cv, numberOfItemsInSection: section)
		item_count_for_section section
	end

	def setup_event_cell(cv, path, cell, ev)
		imageview = cell.contentView.viewWithTag(100)
		timelabel = cell.contentView.viewWithTag(101)
		personlabel = cell.contentView.viewWithTag(102)

		# configure cell
		timelabel.text   = ev.startDate.time_of_day_label.sub('_', ' ').upcase
		# timelabel.sizeToFit
		# w = CGRectGetWidth(timelabel.frame) + 4
		# timelabel.frame = CGRectMake(73-w,0,w,13)

		imageview.image  = Event.image(ev){ cv.reloadItemsAtIndexPaths([path]) }
		personlabel.text = if ev.organizer && !ev.organizer.isCurrentUser
			ev.organizer.name.split[0]
		else
			ev.title
			# Event.painted?(ev) ? "" : 
		end
		cell
	end

	def collectionView(cv, cellForItemAtIndexPath: path)
		kind, ev = thing_at_index_path path
		case kind
		when :event
			return nil unless ev
			cell = cv.dequeueReusableCellWithReuseIdentifier('Appt', forIndexPath:path)
			return setup_event_cell(cv, path, cell, ev)

		when :plus
			cell = cv.dequeueReusableCellWithReuseIdentifier('Plus', forIndexPath:path)
			cell.contentView.viewWithTag(110).text = @paint ? Paints.prompt(@paint) : 'Add friend date'
			cell
		end
	end

	def collectionView(cv, viewForSupplementaryElementOfKind:kind, atIndexPath:path)
		return unless kind == UICollectionElementKindSectionHeader
		view = cv.dequeueReusableSupplementaryViewOfKind(kind, withReuseIdentifier:'Section', forIndexPath:path)
		section_date = sections[path.section]
		view.subviews[0].text = section_date.day_of_week_label
		view.subviews[1].text = section_date.strftime("%m/%d")
		view
	end



	##############
	# improve uikit

	def menu options, canceled = nil, &cb
		puts "menu called"
		UIActionSheet.alert nil, buttons: ['Cancel', nil, *options], success: proc{ |thing|
			cb.call(thing) unless thing == 'Cancel' or thing == :Cancel
		}, cancel: proc{
			canceled.call() if canceled
		}
	end

	def batch_updates &foo
		collectionView.performBatchUpdates(proc{ foo.call(collectionView) }, completion:nil)
	end

end

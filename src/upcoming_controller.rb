LIVE = []


class EventCell < UICollectionReusableView
	def initWithCoder(c)
		super
 		self
	end
end


class UpcomingController < UICollectionViewController


	##################################################################
	# mappings between indexpaths, sections, rows, and calendar events

	def timeframe
		dates = timeframe_dates
		[dates[0], dates[-1] + 24.hours]
	end

	def timeframe_dates
		@timeframe_dates ||= begin
			today = Time.today
			(0..14).map{ |n| today.delta(days: n).start_of_day }
		end
	end

	def load_events
		@timeframe_dates = nil
		@events_by_day = {}
		return unless AuthenticationController.all_authed?

		Event.legit_events(timeframe, proc{ reload }).each do |ev|
			morning = ev.startDate.start_of_day
			section = @events_by_day[morning] ||= []
			section << ev unless section.detect{ |existing| existing.title == ev.title and existing.startDate == ev.startDate }
		end
	end

	def sections
		timeframe_dates
	end

	def events_on_date d
		@events_by_day[d] || []
	end

	def item_count_for_section n
		date = sections[n]
		events = @events_by_day[date] || []
		events_on_date(date).length
	end

	def thing_at_index_path p
		date = sections[p.section]
		ev = events_on_date(date)[p.row]
		return :event, ev if ev
	end

	def remove_event(ev)
		events_on_date(ev.startDate.start_of_day).delete(ev)
	end

	def index_path_for_event(ev)
		id = ev.eventIdentifier
		date = ev.startDate.start_of_day
		section = sections.index(date)
		row = events_on_date(date).index{ |e| e.eventIdentifier == id }
		puts "#{[section, row].inspect}"
		[section,row].nsindexpath
	end


	# cv.insertSections(extra_sections.nsindexset)
	# cv.insertItemsAtIndexPaths(plus_indexes.map(&:nsindexpath))
	# cv.deleteItemsAtIndexPaths(plus_indexes.map(&:nsindexpath))
	# cv.deleteSections(extra_sections.nsindexset)




	############
	# lifecycle

	def self.instance
		@@instance
	end

	def viewDidLoad
		super
		@@instance = self
		puts "viewDidLoad"
		load_events
		collectionView.delegate = self
		collectionView.dataSource = self
		collectionView.contentInset = UIEdgeInsetsMake(20,0,0,0)
		collectionView.gestureRecognizers[2].addTarget(self, action: :longPress)
		view.addGestureRecognizer(UIPanGestureRecognizer.alloc.initWithTarget(self, action: :swipeHandler))
	end

	def swipeHandler sender = nil
		sideMenu.showFromPanGesture(sender)
	end


	def viewWillAppear(animated)
		super
		LIVE[0] = self
		@ekobserver = App.notification_center.observe(EKEventStoreChangedNotification){ |x| reload }
		# navigationController.setToolbarHidden(true,animated:true)
	end

	def viewWillDisappear(animated)
		super
		App.notification_center.unobserve @ekobserver if @ekobserver
	end

	def reload
		puts "reloading events"
  		load_events
  		collectionView.reloadData
		@view_editing = @editing
	end



	############
	# dropped

	def over(text, p)
		# over_section = section_for_point(p)
		# over_time_of_day = time_of_day_for_point(p)
		# return if same same
		# batch_updates {
		#       if section changed
		#		  removed, added = switch_section_droptargets(over_section, over_time_of_day)
		#       else
		# 		  removed, added = switch_tod_droptargets(over_time_of_day)
		#       end
		# 		deleteItemsAtIndexPaths if removed 
		# 		insertItemsAtIndexPaths if added
		# 		highlight!!
		# }
	end

	def dropped(text, p)
		section = section_for_point(p)
		return unless section
		case text
		when /appt/
			alert = BW::UIAlertView.plain_text_input(:title => "Do what?") do |alert|
				add_event_on_date sections[section], alert.plain_text_field.text
			end
			alert.show
		when /friend/
			add_event_on_date sections[section], nil
		else
			add_event_on_date sections[section], text
		end
	end

	def add_event_on_date date, text
		menu %w{ bfst morn lunch aft hpy_hr eve night } do |pressed|
			next unless range = NSDate::HOUR_RANGES[pressed.to_sym]
			start_time = date + range.begin.hours
			if text
				Event.add_event(start_time, nil, text)
			else
				AddressBook.pick :autofocus_search => true do |person|
					Event.add_event(start_time, person) if person
				end
			end
	    end
	end

	def add_event_at_time date, start_time, text, person
		ev = Event.add_event(start_time, person, text)
		collectionView.insertItemsAtIndexPaths(index_path_for_event(ev))
	end

	def section_for_point(p)
		prev_top = nil
		(0..sections.size-1).each do |i|
			path = [i].nsindexpath
			attrs = collectionView.layoutAttributesForSupplementaryElementOfKind(UICollectionElementKindSectionHeader, atIndexPath: path)
			top = attrs.frame.origin.y
			return prev_top if top > p.y
			prev_top = i
		end
		return prev_top
	end



	###################
	# clicking

	def lookup_friend_id friend_id
		abrecord = friend_id && ABAddressBookGetPersonWithRecordID(AddressBook.address_book, friend_id)
		if abrecord
			person = abrecord && AddressBook::Person.new(AddressBook.address_book, abrecord)
			fname = abrecord && person.first_name
			return fname, abrecord
		end
		return nil
	end

	def options_menu_for_event ev, path
		puts ev.inspect
		options = []

		NSLog "have event: #{ev.inspect}"
		friend_id = Event.friend_ab_record_id(ev)
		NSLog "have friend_id: #{friend_id.inspect}"

		fname, abrecord = lookup_friend_id friend_id
		options << fname if fname
		fname ||= "NO NAME"
		options << 'View/Edit Event'

		menu options do |x|
			case x

			when fname
				display_person nil, abrecord

			when 'View/Edit Event'
				view_event ev
			end
		end
	end





	# when 'Add friend'
 #  		AddressBook.pick do |person|
 #  			next unless person
 #  			puts "eventIdentifier: #{ev.eventIdentifier}, person: #{person.inspect}"
 #  			Event.assign(ev.eventIdentifier, person)
 #  			collectionView.reloadItemsAtIndexPaths([path])
 #  		end
	# when 'Unlink friend'
	# 	Event.unassign(ev.eventIdentifier)
	# 		collectionView.reloadItemsAtIndexPaths([path])

	def with_street_address &blk
		BW::Location.get_once do |result|
			@coder ||= CLGeocoder.alloc.init
			@coder.reverseGeocodeLocation(result, completionHandler:lambda{
				|placemarks, error|
				if !error && placemarks[0]
					loc = ABCreateStringWithAddressDictionary(placemarks[0].addressDictionary, false)
					Dispatch::Queue.main.async do
						blk.call(loc)
					end
				end
			})
			# latlng = "#{result.latitude},#{result.longitude}"
			# go_to_url nil, "#{Event.suggestions_url(ev)}&find_loc=#{latlng}"
		end
	end


	def display_suggestions event, navigationController = nil
		with_street_address do |loc|
			url = Event.suggestions_url(event, loc)
			puts "ok: #{url}"
			go_to_url navigationController, url
		end
	end


	def friend_name ev
		return unless friend_id = Event.friend_ab_record_id(ev)
		fname, abrecord = lookup_friend_id friend_id
		fname
	end

	def display_friend_record ev, navigationController
		return unless friend_id = Event.friend_ab_record_id(ev)
		fname, abrecord = lookup_friend_id friend_id
		display_person navigationController, abrecord
	end

	def show_event_menu ev, viewController = nil
		friend_id = Event.friend_ab_record_id(ev)
		fname, abrecord = lookup_friend_id friend_id
		options = []
		options << fname if fname

		if ev.calendar.allowsContentModifications
			options << "edit" << "delete"
		else
			options << "hide"
		end

		options << "Get Suggestions"

		menu options do |x|
			case x

			when 'Get Suggestions'
				nc = viewController.navigationController
				go_to_url nc, Event.suggestions_url(ev)

			when fname
				nc = viewController.navigationController
				display_person nc, abrecord

			when 'edit'
				@eventViewController.editEvent

			when 'delete'
		  		dismissViewControllerAnimated true, completion:lambda{
					path = index_path_for_event(ev)
					remove_event(ev)
			  		Event.delete!(ev)
		  			collectionView.deleteItemsAtIndexPaths([path])
		  		}

			when 'hide'
		  		dismissViewControllerAnimated true, completion:lambda{
					path = index_path_for_event(ev)
					remove_event(ev)
		  			Event.hide_matching(ev)
		  			collectionView.deleteItemsAtIndexPaths([path])		  			
		  		}
			end
		end
	end

			# when '+friend'
		 #  		AddressBook.pick do |person|
		 #  			next unless person
		 #  			Event.assign(ev.eventIdentifier, person)
		 #  			collectionView.reloadItemsAtIndexPaths([path])
		 #  		end
			# when 'Unlink friend'
			# 	Event.unassign(ev.eventIdentifier)
	  # 			collectionView.reloadItemsAtIndexPaths([path])


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
		end
	end

	# def touchesMoved(t, withEvent: e)
	# 	return super unless @dragging
	# end

	# def gestureRecognizer(x, shouldRecevieTouch:t)
	# 	!@dragging
	# end

	# def new_longPress
	# 	make popping sound
	# 	@dragging = true
	# 	@img = ...
	# 	add.SubView(@img)
	# end


	def longPress
		gr = collectionView.gestureRecognizers[2]
		return unless gr.state == UIGestureRecognizerStateBegan

		p = gr.locationInView(collectionView)
		path = collectionView.indexPathForItemAtPoint(p)

		return unless path
    	kind, ev = thing_at_index_path(path)
    	return unless kind == :event and ev
    	options_menu_for_event ev, path
	end



	##############
	# data source

	def numberOfSectionsInCollectionView(cv)
		sections.length
	end

	def collectionView(cv, numberOfItemsInSection: section)
		item_count_for_section section
	end

	# TODO: move shadow stuff into a custom cell initializer
	def setup_event_cell(cv, path, cell, ev)
		imageview = cell.contentView.viewWithTag(100)
		timelabel = cell.contentView.viewWithTag(101)
		personlabel = cell.contentView.viewWithTag(102)

		pl = cell.contentView.viewWithTag(112).layer
		if !pl.sublayers || !pl.sublayers[0].name
			l = CALayer.layer
			l.name = "Shadow"
			l.contents = UIImage.imageNamed('blackrect.png').CGImage
			l.frame = CGRectMake(-6,-12,85,90)
			# pl.frame
			pl.insertSublayer(l, atIndex:0)
		end

		timelabel.text   = ev.startDate.time_of_day_label

		imageview.image  = Event.image(ev){ cv.reloadItemsAtIndexPaths([path]) }
		personlabel.text = ev.title
		cell
	end

	def collectionView(cv, cellForItemAtIndexPath: path)
		kind, ev = thing_at_index_path path
		case kind
		when :event
			return nil unless ev
			cell = cv.dequeueReusableCellWithReuseIdentifier('Appt', forIndexPath:path)
			return setup_event_cell(cv, path, cell, ev)
		end
	end

	def collectionView(cv, viewForSupplementaryElementOfKind:kind, atIndexPath:path)
		return unless kind == UICollectionElementKindSectionHeader
		view = cv.dequeueReusableSupplementaryViewOfKind(kind, withReuseIdentifier:'Section', forIndexPath:path)
		section_date = sections[path.section]
		view.subviews[0].text = section_date.day_of_week_label
		view.subviews[1].text = section_date.strftime("%b %d")
		view
	end



	##############
	# improve uikit

	def view_event ev
		return false unless ev
		@eventViewController = AppointmentViewController.alloc.initWithEventAndParent(ev, self)
		display_controller_in_navcontroller( @eventViewController )
	end

	def go_to_url nc = nil, url
		NSLog "%@", "going to URL: [#{url}]"
		nsurl = NSURL.URLWithString(url)
		NSLog "%@", "nsurl: #{nsurl.inspect}"
		nsreq = NSURLRequest.requestWithURL(nsurl)
		NSLog "%@", "nsreq: #{nsreq.inspect}"

		bounds = UIScreen.mainScreen.bounds
		rect = CGRectMake(0, 0, bounds.width, bounds.height);

    	uiWebView = UIWebView.alloc.initWithFrame(rect)
    	uiWebView.loadRequest(nsreq)
		NSLog "%@", "uiWebView: #{uiWebView.inspect}"

		vc = UIViewController.alloc.init
    	vc.view.addSubview(uiWebView)
		display_controller_in_navcontroller(vc, nc)
	end

	def display_person nc = nil, ab_person
		v = ABPersonViewController.alloc.init
		v.personViewDelegate = self
		v.displayedPerson = ab_person
		display_controller_in_navcontroller(v, nc)
	end

	def display_controller_in_navcontroller c, nc = nil, pos = "Left"
		return nc.pushViewController(c, animated: true) if nc
		nc = UINavigationController.alloc.initWithRootViewController(c)

		presentViewController(nc, animated: true, completion:lambda{
			c.navigationItem.backBarButtonItem = UIBarButtonItem.alloc.initWithTitle("Done", style:UIBarButtonItemStylePlain, target:self, action: :dismissViewController)
			c.navigationItem.send("setLeftBarButtonItem", UIBarButtonItem.alloc.initWithBarButtonSystemItem(UIBarButtonSystemItemDone, target:self, action: :dismissViewController))
		})
	end

	def dismissViewController
		dismissViewControllerAnimated true, completion:nil
	end

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

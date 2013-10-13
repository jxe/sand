LIVE = []

class UpcomingController < UICollectionViewController

	############
	# lifecycle

	def self.instance
		@@instance
	end

	def viewDidLoad
		super
		@display_model = CalendarDisplayModel.new
		@@instance = self
		puts "viewDidLoad"
		@display_model.load_events
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
  		@display_model.load_events
  		collectionView.reloadData
	end



	############
	# dropped

	def dragwatcher
		@map = onscreen_section_map
		@over_section = nil
		self
	end

	def over(text, p)
		y = p.y.to_i
		s = @map[y]
		open_up_section s
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
		return dragCanceled unless date = date_for_point(p)
		path = collectionView.indexPathForItemAtPoint(p)
    	kind, ev = @display_model.thing_at_index_path(path)
    	return dragCanceled unless kind == :placeholder
    	range = NSDate::HOUR_RANGES[ev.to_sym]
    	return dragCanceled unless range
		start_time = date + range.begin.hours	
		with_person_and_title_for_droptext text do |person, title|
			if title
				ev, path = @display_model.add_event start_time, person, text
				open_up_section nil, lambda{
					collectionView.insertItemsAtIndexPaths([path])			
				}
			else
				dragCanceled
			end
		end
	end

	def add_event_at_time start_time, text, person
		ev, path = @display_model.add_event start_time, person, text
		collectionView.insertItemsAtIndexPaths([path])
	end

	# no effect if it's open already
	def open_up_section s, cb = nil
		return if s == @display_model.open_section
		return if @opening_section
		@opening_section = true
		collectionView.performBatchUpdates(lambda{
			opened, closed = @display_model.open_up_section s
			collectionView.insertItemsAtIndexPaths(opened)
			collectionView.deleteItemsAtIndexPaths(closed)
			cb && cb.call
		}, completion: lambda{ |x|
			@map = onscreen_section_map
			@opening_section = false
		})
	end

	def dragCanceled
		open_up_section nil
	end

	def with_person_and_title_for_droptext text, &cb
		case text
		when /appt/
			alert = BW::UIAlertView.plain_text_input(:title => "Do what?") do |alert|
				cb.call nil, alert.plain_text_field.text
			end
			alert.show			
		when /friend/
			AddressBook.pick :autofocus_search => true do |person|
				if person
					cb.call(person, person.composite_name) 
				else
					cb.call(nil, nil)
				end
			end
		else
			cb.call(nil, text)
		end
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


	##############
	# wiring

	def collectionView(cv, didSelectItemAtIndexPath:path)
		kind, thing = @display_model.thing_at_index_path path
		view_event(thing) if kind == :event
	end

	def longPress
		gr = collectionView.gestureRecognizers[2]
		return unless gr.state == UIGestureRecognizerStateBegan
		p = gr.locationInView(collectionView)
		path = p && collectionView.indexPathForItemAtPoint(p)
		cell = path && collectionView.cellForItemAtIndexPath(path)
    	kind, ev = @display_model.thing_at_index_path(path)
		return unless cell

		# okay we were on a thing!

		# make popping sound
		gr.enabled = false
		collectionView.startDragging(p, cell) do |endpt|
			if section_for_point(endpt) != path.section
				delete_or_hide_event(ev, path)
				gr.enabled = true
			end
		end
	end



	##############
	# data source

	# cv.insertSections(extra_sections.nsindexset)
	# cv.insertItemsAtIndexPaths(plus_indexes.map(&:nsindexpath))
	# cv.deleteItemsAtIndexPaths(plus_indexes.map(&:nsindexpath))
	# cv.deleteSections(extra_sections.nsindexset)

	def date_for_point p
		section = section_for_point(p)
		section && @display_model.sections[section]
	end

	def top_of_header_for_section i
		collectionView.layoutAttributesForSupplementaryElementOfKind(UICollectionElementKindSectionHeader, atIndexPath: [i].nsindexpath).frame.origin.y
	end

	def onscreen_section_map
		top = collectionView.contentOffset.y.to_i
		bottom = top + collectionView.frame.height.to_i
		map = {}
		next_section = 0

		(top..bottom).each do |y|
			next_section += 1 unless top_of_header_for_section(next_section) > y
			map[y] = next_section - 1
		end

		map
	end

	def section_for_point(p)
		prev_top = nil
		(0..@display_model.sections.size-1).each do |i|
			path = [i].nsindexpath
			attrs = collectionView.layoutAttributesForSupplementaryElementOfKind(UICollectionElementKindSectionHeader, atIndexPath: path)
			top = attrs.frame.origin.y
			return prev_top if top > p.y
			prev_top = i
		end
		return prev_top
	end

	def delete_or_hide_event ev, path = nil
		path ||= @display_model.index_path_for_event(ev)
		@display_model.remove_event(ev)
		collectionView.deleteItemsAtIndexPaths([path])
	end

	def numberOfSectionsInCollectionView(cv)
		@display_model.sections.length
	end

	def collectionView(cv, numberOfItemsInSection: section)
		@display_model.item_count_for_section section
	end

	def collectionView(cv, cellForItemAtIndexPath: path)
		kind, ev = @display_model.thing_at_index_path path
		cell = cv.dequeueReusableCellWithReuseIdentifier('Appt', forIndexPath:path)
		case kind
		when :event;       cell.as_event(ev, cv, path)
		when :placeholder; cell.as_placeholder(ev)
		end
		cell
	end

	def collectionView(cv, viewForSupplementaryElementOfKind:kind, atIndexPath:path)
		return unless kind == UICollectionElementKindSectionHeader
		view = cv.dequeueReusableSupplementaryViewOfKind(kind, withReuseIdentifier:'Section', forIndexPath:path)
		section_date = @display_model.sections[path.section]
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

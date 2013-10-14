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

	def dragStart
		puts "dragStart"
		@map = onscreen_section_map
		@over_section = nil
		self
	end

	def dragOver(text, p)
		puts "dragOver"
		y = p.y.to_i
		return unless s = @map[y]
		if @over_section != s
			open_up_section nil if @over_section
			@over_section = s
			@hover_timer.invalidate if @hover_timer

			# set a timer... if we're still over the same
			# section, open it and scroll to reveal it
			@hover_timer = NSTimer.scheduledTimerWithTimeInterval(0.3,
			        :target   => self,
			        :selector => :section_hovered,
			        :userInfo => nil,
			        :repeats  => false)
		end
	end

	def section_hovered
		open_up_section @over_section, :on_complete => lambda{ reveal_section @over_section }
	end

		
		# over_time_of_day = time_of_day_for_point(p)
		# return if same same
		# 		  removed, added = switch_tod_droptargets(over_time_of_day)


	# no effect if it's open already
	def open_up_section s, options = {}
		return if s == @display_model.open_section
		return if @opening_section
		@opening_section = true
		collectionView.performBatchUpdates(lambda{
			opened, closed = @display_model.open_up_section s
			collectionView.insertItemsAtIndexPaths(opened)
			collectionView.deleteItemsAtIndexPaths(closed)
			options[:also_animate] && options[:also_animate].call
		}, completion: lambda{ |x|
			@map = onscreen_section_map
			@opening_section = false
			options[:on_complete] && options[:on_complete].call
		})
	end

	def scrollViewDidEndScrollingAnimation(cv)
		puts "remap!"
		@map = onscreen_section_map
	end

	def reveal_section s
		screen_top = collectionView.contentOffset.y.to_i + 40  # for the status bar
		screen_height = collectionView.frame.height.to_i  # for the dock
		screen_bottom = screen_top + screen_height - 50
		section_top = top_of_header_for_section(s)
		section_bottom = top_of_header_for_section(s+1)
		return unless section_top and section_bottom

		if screen_bottom < section_bottom
			# scroll down
			pos = CGPointMake(0, section_bottom - screen_height + 50)
			collectionView.setContentOffset(pos, animated: true)
		elsif screen_top > section_top
			# scroll up
			pos = CGPointMake(0, section_top - 40)
			collectionView.setContentOffset(pos, animated: true)
		end
	end







	def dropped(text, p)
		return dragCanceled unless placeholder = thing_at_point(p)
		return dragCanceled unless Placeholder === placeholder
		with_person_and_title_for_droptext text do |person, title|
			if title
				open_up_section nil, :also_animate => lambda{
					ev = @display_model.add_event placeholder.startDate, person, text
					path = @display_model.index_path_for_event(ev)
					collectionView.insertItemsAtIndexPaths([path])
				}
			else
				dragCanceled
			end
		end
	end

	def dragCanceled
		@hover_timer.invalidate if @hover_timer
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
		thing = @display_model.thing_at_index_path path
		view_event(thing) if EKEvent === thing
	end

	def longPress
		gr = collectionView.gestureRecognizers[2]
		p = gr.locationInView(collectionView)
		case gr.state
		when UIGestureRecognizerStateBegan
			@press_thing = thing = thing_at_point(p)
			return gr.reset unless thing and EKEvent === thing

			@press_path = path = collectionView.indexPathForItemAtPoint(p)
			cell = path && collectionView.cellForItemAtIndexPath(path)
			# okay we were on a thing!
			# make popping sound
			@longpress_section = path.section
			@hover_timer = NSTimer.scheduledTimerWithTimeInterval(0.6,
						        :target   => self,
						        :selector => :hover_after_longPress,
						        :userInfo => nil,
						        :repeats  => false)

			imgview = cell.contentView.viewWithTag(100)
			@dragging_img = UIImageView.alloc.initWithImage(imgview.image)
			@dragging_img.frame = CGRect.make(origin: @dragging_img.frame.origin, size: CGSizeMake(80,80))
			@dragging_img.center = p
			collectionView.scrollEnabled = false
			collectionView.addSubview @dragging_img

		when UIGestureRecognizerStateChanged
			@dragging_img.center = p

		when UIGestureRecognizerStateEnded
			@dragging_img.removeFromSuperview
			@dragging_img = nil
			collectionView.scrollEnabled = true
			endpt = p
			if section_for_point(endpt) != @press_path.section
				unless @display_model.open_section
					delete_or_hide_event(@press_thing, @press_path)
				else
					path = @display_model.index_path_for_event(ev)
					open_up_section nil, :also_animate => lambda{
						@display_model.remove_event(ev)
						collectionView.deleteItemsAtIndexPaths([path])
					}
				end
			else
				placeholder = thing_at_point(endpt)
				if placeholder && Placeholder === placeholder
					open_up_section nil, :also_animate => lambda{
						# mod the event
						old_path = @display_model.index_path_for_event(@press_thing)
						@press_thing.startDate = placeholder.startDate
						Event.save(@press_thing)
						collectionView.deleteItemsAtIndexPaths([old_path])
						@display_model.moved(@press_thing)
						new_path = @display_model.index_path_for_event(@press_thing)
						collectionView.insertItemsAtIndexPaths([new_path])
					}
				else
					open_up_section nil
				end
			end
		end
	end

	def hover_after_longPress
		return unless @dragging_img and @press_path and @longpress_section
		if section_for_point(@dragging_img.center) == @press_path.section
			open_up_section @longpress_section
		end
	end


	##############
	# data source

	# cv.insertSections(extra_sections.nsindexset)
	# cv.insertItemsAtIndexPaths(plus_indexes.map(&:nsindexpath))
	# cv.deleteItemsAtIndexPaths(plus_indexes.map(&:nsindexpath))
	# cv.deleteSections(extra_sections.nsindexset)

	def thing_at_point(p)
		path = collectionView.indexPathForItemAtPoint(p)		
    	path && @display_model.thing_at_index_path(path)
	end

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
		ev = @display_model.thing_at_index_path path
		cell = cv.dequeueReusableCellWithReuseIdentifier('Appt', forIndexPath:path)
		case ev
		when EKEvent;     cell.as_event(ev, cv, path)
		when Placeholder; cell.as_placeholder(ev.label)
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

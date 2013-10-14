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
		# @ekobserver = App.notification_center.observe(EKEventStoreChangedNotification){ |x| reload }
		# navigationController.setToolbarHidden(true,animated:true)
	end

	def viewWillDisappear(animated)
		super
		# App.notification_center.unobserve @ekobserver if @ekobserver
	end

	def reload
  		@display_model.load_events
  		collectionView.reloadData
	end


	####################################
	# NOT TOO CRAZY DRAGGING / REORG CODE

	def scrollViewDidEndScrollingAnimation(cv)
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




	####################################
	# CRAZY DRAGGING / REORG CODE

	# @map -- a mapping from y pixels to sections, 
	#         used during drag and updated on scroll
    #
    # @over_section -- are we hovering over a section?
    # open_section -- is a section open?

    def animate_section_opened s
		@display_model.hover(s)
		collectionView.insertItemsAtIndexPaths(@display_model.placeholder_positions)    		
    end



    def consider_revealing_at(p, special_thing = nil, limit_to_section = nil)
    	@was_over_section = @over_section
		@over_section = @map[p.y.to_i]
    	if @was_over_section != @over_section
    		delay = limit_to_section ? 0.6 : 0.3
    		if !limit_to_section or limit_to_section == @over_section
	    		@dragging_img && @dragging_img.layer.opacity = 1.0
	    		open_section_if_still_over(@over_section, :in => delay)
	    	elsif limit_to_section
	    		@dragging_img && @dragging_img.layer.opacity = 0.5
	    	end

			push_animation{ animate_section_closed } if @was_over_section

    	else
    		@old_thing = @over_thing
    		@over_thing = thing_at_point(p)
    		return if @over_thing == special_thing
    		if @over_thing and @old_thing != @over_thing
	    		return if @animations_running
    			if @display_model.date_open and @over_thing.startDate.start_of_day == @display_model.date_open
					puts "date of thing is open"
    				push_animation{
    					old_location = @display_model.special_placeholder_position
    					puts "calling hover..: #{@over_thing.inspect}"
						@display_model.hover(@over_section, @over_thing)
 						new_location = @display_model.special_placeholder_position
    					old_location && collectionView.deleteItemsAtIndexPaths([old_location])
    					new_location && collectionView.insertItemsAtIndexPaths([new_location])
    				}
    				push_animation{
    					@old_thing = @over_thing = thing_at_point(p)
    				}
    			end
    		end
    	end
    end


	def dragOver(text, p)
		consider_revealing_at(p)
	end


	def open_section_if_still_over(s, options = {})
		@requested_section = s
		@hover_timer.invalidate if @hover_timer
		options[:in] ||= 0.3
		@hover_timer = NSTimer.scheduledTimerWithTimeInterval(options[:in],
		        :target   => self,
		        :selector => :check_if_still_over_section_after_time,
		        :userInfo => nil,
		        :repeats  => false)
	end

	def check_if_still_over_section_after_time
		puts "@was_over_section: #{@was_over_section}; @over_section: #{@over_section}"
		return unless @requested_section == @over_section
		push_animation{ animate_section_opened(@over_section) }
		push_animation{ reveal_section @over_section }
	end






    def animate_section_closed
    	return unless @display_model.date_open
    	positions = @display_model.placeholder_positions
    	@display_model.hover nil
		collectionView.deleteItemsAtIndexPaths(positions)
    end

    # TODO: unused
    # def animate_section_switch new_section
    # 	perform_animation_pausing_hover_detection{
	#     	positions = @display_model.placeholder_positions
	#     	@display_model.hover nil
	# 		collectionView.deleteItemsAtIndexPaths(positions)
	# 		@display_model.hover(new_section)
	# 		collectionView.insertItemsAtIndexPaths(@display_model.placeholder_positions)
    # 	}
    # end



	def longPress
		gr = collectionView.gestureRecognizers[2]
		p = gr.locationInView(collectionView)
		case gr.state
		when UIGestureRecognizerStateBegan
			@press_thing = thing = thing_at_point(p)
			return gr.reset unless thing and EKEvent === thing

			@press_path = path = collectionView.indexPathForItemAtPoint(p)
			@press_cell = cell = path && collectionView.cellForItemAtIndexPath(path)
			# okay we were on a thing!
			# make popping sound

			@press_cell.layer.opacity = 0.2
			@map = onscreen_section_map
			@over_section = nil
			consider_revealing_at(p, @press_thing, @press_path.section)

			imgview = cell.contentView.viewWithTag(100)
			@dragging_img = UIImageView.alloc.initWithImage(imgview.image)
			@dragging_img.frame = CGRect.make(origin: @dragging_img.frame.origin, size: CGSizeMake(80,80))
			@dragging_img.center = p
			collectionView.scrollEnabled = false
			collectionView.addSubview @dragging_img

		when UIGestureRecognizerStateChanged
			@dragging_img.center = p
			consider_revealing_at(p, @press_thing, @press_path.section)

		when UIGestureRecognizerStateEnded
			@dragging_img.removeFromSuperview
			@dragging_img = nil
			@press_cell.layer.opacity = 1.0
			collectionView.scrollEnabled = true
			endpt = p
			if section_for_point(endpt) != @press_path.section
				unless @display_model.date_open
					delete_or_hide_event(@press_thing, @press_path)
				else
					push_animation{ speed(1.5); delete_or_hide_event(@press_thing, @press_path) }
					push_animation{ speed(3.0); animate_section_closed }
				end
			else
				placeholder = thing_at_point(endpt)
				end_path = collectionView.indexPathForItemAtPoint(endpt)
				if placeholder && Placeholder === placeholder
					# they dropped on a placeholder
					push_animation{
						speed(1.5)
						# delete from old location and replace placeholder
						old_path = @display_model.index_path_for_event(@press_thing)
						collectionView.deleteItemsAtIndexPaths([old_path])
						@display_model.move_to_placeholder(@press_thing, placeholder)
						collectionView.reloadItemsAtIndexPaths([end_path])
					}
					push_animation { speed(3.0); animate_section_closed }
			else
					push_animation { animate_section_closed }
				end
			end
		end
	end

	def dragCanceled
		@hover_timer.invalidate if @hover_timer
		puts "dragCanceled"
		push_animation{ animate_section_closed }
	end


	def dropped(text, p)
		return dragCanceled unless placeholder = thing_at_point(p)
		return dragCanceled unless Placeholder === placeholder
		with_person_and_title_for_droptext text do |person, title|
			if title
				path = collectionView.indexPathForItemAtPoint(p)
				push_animation{
					puts "reloading event"
					speed(1.5);
					@display_model.add_event_at_placeholder(placeholder, person, title)
					collectionView.reloadItemsAtIndexPaths([path])					
				}
				push_animation{ 
					puts "closing section"
					speed(3.0);
					animate_section_closed
				}
			else
				dragCanceled
			end
		end
	end

	def dragStart
		@map = onscreen_section_map
		@over_section = nil
	end




	###################
	# helpers


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



	##############
	# data source

	# cv.insertSections(extra_sections.nsindexset)
	# cv.insertItemsAtIndexPaths(plus_indexes.map(&:nsindexpath))
	# cv.deleteItemsAtIndexPaths(plus_indexes.map(&:nsindexpath))
	# cv.deleteSections(extra_sections.nsindexset)

	def thing_at_point(p)
		path = collectionView.indexPathForItemAtPoint(p)
		# puts "got path: #{path.inspect}"
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
		case ev
		when EKEvent;
			cell = cv.dequeueReusableCellWithReuseIdentifier('Appt', forIndexPath:path)
			cell.as_event(ev, cv, path)
		when Placeholder;
			cell = cv.dequeueReusableCellWithReuseIdentifier('Placeholder', forIndexPath:path)
			cell.as_placeholder(ev.label)
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

	def display_suggestions event, navigationController = nil
		uiWebView = push_webview(navigationController)
		with_street_address do |loc|
			url = Event.suggestions_url(event, loc)
			nsurl = NSURL.URLWithString(url)
			nsreq = NSURLRequest.requestWithURL(nsurl)
			uiWebView.loadRequest(nsreq)
		end
	end

	def push_webview nc = nil
		bounds = UIScreen.mainScreen.bounds
		rect = CGRectMake(0, 0, bounds.width, bounds.height);

    	uiWebView = UIWebView.alloc.initWithFrame(rect)
    	
		vc = UIViewController.alloc.init
    	vc.view.addSubview(uiWebView)
		display_controller_in_navcontroller(vc, nc)
		return uiWebView
	end

	def go_to_url nc = nil, url
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

	def push_animation &blk
		@animation_stack ||= []
		@animation_stack << blk
		run_animations unless @animations_running
	end

	def speed s
		collectionView.viewForBaselineLayout.layer.setSpeed(s)
	end

	def run_animations
		@animations_running = true
		layer = collectionView.viewForBaselineLayout.layer
		@baseline_animation_speed = layer.speed
		collectionView.performBatchUpdates(@animation_stack.shift, completion: lambda{ |x|
			if @animation_stack.empty?
				@animations_running = false
				@map = onscreen_section_map
				layer.setSpeed @baseline_animation_speed
			else
				run_animations
			end
		})
	end

end

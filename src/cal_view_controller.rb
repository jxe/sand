class DayHeaderReusableView < UICollectionReusableView; attr_accessor :section; end
class SandFlowLayout < UICollectionViewFlowLayout; end

class CalViewController < UICollectionViewController

	############
	# lifecycle

	attr_reader :animations_running

	def addDragManager(mgr, *grArgs)
		(@dragManagers ||= []) << mgr
		view.addGestureRecognizer(mgr.newGestureRecognizer(*grArgs))
	end

	def viewDidLoad
		super

		# set up the screen
		collectionView.contentInset = UIEdgeInsetsMake(26,0,0,0)
		@dock_controller = self.storyboard.instantiateViewControllerWithIdentifier('Dock')
		addChildViewController(@dock_controller)
		@dock_controller.collectionView.frame = CGRectMake(0, 490, 320, 60)
		view.addSubview(@dock_controller.collectionView)

		# populate myself
		@cvm = CalViewModel.new
		collectionView.delegate = self
		collectionView.dataSource = self
		@cvm.load_events

		# add the drag gestures from the dock
		mgr = DockAddDragManager.new(view, collectionView, @dock_controller, self)
		addDragManager(mgr, UIPanGestureRecognizer)

		# add the reordering longpress gestures
		mgr = ReorderingDragManager.new(view, collectionView, @dock_controller, self)
		addDragManager(mgr, UILongPressGestureRecognizer)

		# add the swiping main menu gesture
		view.addGestureRecognizer(UIPanGestureRecognizer.alloc.initWithTarget(self, action: :swipeHandler))
	end




	def swipeHandler sender = nil
		sideMenu.showFromPanGesture(sender)
	end


	def viewWillAppear(animated)
		super
		# @ekobserver = App.notification_center.observe(EKEventStoreChangedNotification){ |x| reload }
		# navigationController.setToolbarHidden(true,animated:true)
	end

	def viewWillDisappear(animated)
		super
		# App.notification_center.unobserve @ekobserver if @ekobserver
	end

	def reload
  		@cvm.load_events
  		collectionView.reloadData
	end


	####################################
	# ANIMATED METHODS

	def scrollViewDidEndScrollingAnimation(cv)
		@dragManager && @dragManager.update_map
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

	def animate_rm ev
		push_animation {
			if path = @cvm.index_path_for_event(ev)
				@cvm.remove_event(ev)
				collectionView.deleteItemsAtIndexPaths([path])
			end
		}
	end

    def animate_open s
    	return if @cvm.date_open
    	push_animation{
			@cvm.hover s
			collectionView.insertItemsAtIndexPaths(@cvm.placeholder_positions)
    	}
		push_animation{
			reveal_section s
		}
    end

    def animate_close
    	push_animation{
	    	if @cvm.date_open
		    	positions = @cvm.placeholder_positions
		    	@cvm.hover nil
				collectionView.deleteItemsAtIndexPaths(positions)
			end
    	}
    end

    def animate_rm_and_close thing_was
    	return animate_rm(thing_was) unless @cvm.date_open
		push_animation{
			pos = @cvm.index_path_for_event(thing_was)
	    	positions = @cvm.placeholder_positions + [pos]
			@cvm.remove_event(thing_was)
	    	@cvm.hover nil
			collectionView.deleteItemsAtIndexPaths(positions)
		}
    end

	def animate_add_and_close placeholder, person, title
		push_animation{
			path = @cvm.index_path_for_thing(placeholder)
			@cvm.add_event_at_placeholder(placeholder, person, title)
			path && collectionView.reloadItemsAtIndexPaths([path])
		}
		animate_close
	end

	def animate_insert_and_close ev, person, title
		push_animation{
			path = @cvm.index_path_for_thing(ev)
			@cvm.add_event_before_event(ev, person, title)
			collectionView.insertItemsAtIndexPaths([path])
		}
		animate_close
	end

	def animate_mv_and_close thing_was, placeholder
		end_path = @cvm.index_path_for_thing(placeholder)
		case placeholder
		when Placeholder
			push_animation{
				# delete from old location and replace placeholder
				old_path = @cvm.index_path_for_event(thing_was)
				collectionView.deleteItemsAtIndexPaths([old_path])
				@cvm.move_to_placeholder(thing_was, placeholder)
				collectionView.reloadItemsAtIndexPaths([end_path])
			}
			animate_close
		else
			push_animation{
				# delete from old location and replace placeholder
				old_path = @cvm.index_path_for_event(thing_was)
				new_loc = @cvm.move_before_event(thing_was, placeholder)
				new_path = [end_path.section, new_loc].nsindexpath
				collectionView.deleteItemsAtIndexPaths([old_path])
				collectionView.insertItemsAtIndexPaths([new_path])
			}
			animate_close
		end
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

	def push_animation &blk
		@animation_stack ||= []
		@animation_stack << blk
		run_animations unless @animations_running
	end

	def speed s
		# collectionView.viewForBaselineLayout.layer.setSpeed(s)
	end

	def run_animations
		@animations_running = true
		layer = collectionView.viewForBaselineLayout.layer
		@baseline_animation_speed = layer.speed
		collectionView.performBatchUpdates(@animation_stack.shift, completion: lambda{ |x|
			if @animation_stack.empty?
				@animations_running = false
				@dragManagers.each(&:update_map)
				layer.setSpeed @baseline_animation_speed
			else
				run_animations
			end
		})
	end


	####################################

	def section_open
		@cvm.date_open
	end

	###################
	# helpers

    # def copy_view view
    # 	archived = NSKeyedArchiver.archivedDataWithRootObject(view)
    # 	return NSKeyedUnarchiver.unarchiveObjectWithData(archived)
    # end


	###################
	# clicking

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

	def reverse_geocode loc, &blk
		@cached_geocodes ||= {}
		close = @cached_geocodes.keys.select{ |l| l.distanceFromLocation(loc) < 1000 }
		if not close.empty?
			blk.call(@cached_geocodes[close.first])
		else
			@coder ||= CLGeocoder.alloc.init
			@coder.reverseGeocodeLocation(loc, completionHandler:lambda{
				|placemarks, error|
				if !error && placemarks[0]
					addr = ABCreateStringWithAddressDictionary(placemarks[0].addressDictionary, false)
					@cached_geocodes[loc] = addr
					blk.call(addr)
				end
			})
		end
	end

	def with_location &blk
		blk.call(@cached_location) if @cached_location
		BW::Location.get_once(significant: true) do |result|
			blk.call(@cached_location = result)
		end
	end

	def with_street_address &blk
		with_location{ |loc| reverse_geocode(loc){ |addr| blk.call(addr) } }
	end

	def lookup_friend_id friend_id
		abrecord = friend_id && ABAddressBookGetPersonWithRecordID(AddressBook.address_book, friend_id)
		if abrecord
			person = abrecord && AddressBook::Person.new(AddressBook.address_book, abrecord)
			fname = abrecord && person.composite_name
			return fname, abrecord
		end
		return nil
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
		thing = @cvm.thing_at_index_path path
		view_event(thing) if EKEvent === thing
	end



	##############
	# data source

	def thing_at_point(p)
		path = collectionView.indexPathForItemAtPoint(p)
    	path && @cvm.thing_at_index_path(path)
	end

	def date_for_point p
		section = section_for_point(p)
		section && @cvm.sections[section]
	end

	def top_of_header_for_section i
		collectionView.layoutAttributesForSupplementaryElementOfKind(UICollectionElementKindSectionHeader, atIndexPath: [i].nsindexpath).frame.origin.y
	end

	def section_for_point(p)
		prev_top = nil
		(0..@cvm.sections.size-1).each do |i|
			path = [i].nsindexpath
			attrs = collectionView.layoutAttributesForSupplementaryElementOfKind(UICollectionElementKindSectionHeader, atIndexPath: path)
			top = attrs.frame.origin.y
			return prev_top if top > p.y
			prev_top = i
		end
		return prev_top
	end


	def numberOfSectionsInCollectionView(cv)
		@cvm.sections.length
	end

	def collectionView(cv, numberOfItemsInSection: section)
		@cvm.item_count_for_section section
	end

	def collectionView(cv, cellForItemAtIndexPath: path)
		puts "redrawing at #{path.inspect}"
		ev = @cvm.thing_at_index_path path
		case ev
		when EKEvent;
			cell = cv.dequeueReusableCellWithReuseIdentifier('Appt', forIndexPath:path)
			cell.as_event(ev, cv, path)
		when Placeholder;
			cell = cv.dequeueReusableCellWithReuseIdentifier('Appt', forIndexPath:path)
			cell.as_placeholder(ev.label)
		end
		cell
	end

	def collectionView(cv, viewForSupplementaryElementOfKind:kind, atIndexPath:path)
		return unless kind == UICollectionElementKindSectionHeader
		@section_cells ||= {}
		view = cv.dequeueReusableSupplementaryViewOfKind(kind, withReuseIdentifier:'Section', forIndexPath:path)
		view.section = path.section
		section_date = @cvm.sections[path.section]
		view.subviews[0].text = section_date.day_of_week_label
		view.subviews[1].text = section_date.strftime("%b %d").upcase
		@section_cells[path.section] = view
		view
	end



	##############
	# improve uikit

	def view_event ev
		return false unless ev
		@eventViewController = AppointmentViewController.alloc.initWithEventAndParent(ev, Event.event_store, self)
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

	def was_modified(ev)
		reload
	end

	def menu options, canceled = nil, &cb
		UIActionSheet.alert nil, buttons: ['Cancel', nil, *options], success: proc{ |thing|
			cb.call(thing) unless thing == 'Cancel' or thing == :Cancel
		}, cancel: proc{
			canceled.call() if canceled
		}
	end

end

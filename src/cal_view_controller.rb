class DayHeaderReusableView < UICollectionReusableView; attr_accessor :section; end
class SandFlowLayout < UICollectionViewFlowLayout; end

class CalViewController < UICollectionViewController
	include ViewControllerImprovements
	include CollectionViewControllerImprovements



	############
	# lifecycle

	def viewDidLoad
		super

		# set up the screen
		collectionView.contentInset = UIEdgeInsetsMake(26,0,0,0)
		@dock_controller = self.storyboard.instantiateViewControllerWithIdentifier('Dock')
		addChildViewController(@dock_controller)
		dock_height = 53
		dock_y = view.frame.size.height - dock_height
		@dock_controller.collectionView.frame = CGRectMake(0, dock_y, view.frame.size.width, dock_height)
		view.addSubview(@dock_controller.collectionView)

		# populate myself
		@cvm = CalViewModel.new
		collectionView.delegate = self
		collectionView.dataSource = self
		@cvm.load_events

		# add the drag gestures from the dock
		mgr = DragUpToAdd.new(view, collectionView, @dock_controller, self)
		addDragManager(mgr, UIPanGestureRecognizer)

		# add the reordering longpress gestures
		mgr = DragToReorder.new(view, collectionView, @dock_controller, self)
		addDragManager(mgr, UILongPressGestureRecognizer)

		# add the swiping main menu gesture
		view.addGestureRecognizer(UIPanGestureRecognizer.alloc.initWithTarget(self, action: :swipeHandler))
	end

	def swipeHandler sender = nil
		sideMenu.showFromPanGesture(sender)
	end


	def viewWillAppear(animated)
		super
		@animator = UIDynamicAnimator.alloc.initWithReferenceView(view.window)
		@animator.delegate = self
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

	def animate_add_and_close placeholder, person, title, img = nil
		push_animation{
			path = @cvm.index_path_for_thing(placeholder)
			@last_ev = @cvm.add_event_at_placeholder(placeholder, person, title)
			path && collectionView.reloadItemsAtIndexPaths([path])
	    	if @cvm.date_open
		    	positions = @cvm.placeholder_positions
		    	@cvm.hover nil
				collectionView.deleteItemsAtIndexPaths(positions)
			end
			if img
				loc = @cvm.index_path_for_thing(@last_ev)
				cell = collectionView.cellForItemAtIndexPath(loc)
				snap_to img, cell.center
			end
		}
	end

	def animate_insert_and_close ev, person, title, img = nil
		push_animation{
	    	if @cvm.date_open
		    	positions = @cvm.placeholder_positions
				@last_ev = @cvm.add_event_before_event(ev, person, title)
		    	@cvm.hover nil
				collectionView.deleteItemsAtIndexPaths(positions)
				path = @cvm.index_path_for_thing(@last_ev)
				collectionView.insertItemsAtIndexPaths([path])
			else
				path = @cvm.index_path_for_thing(ev)
				@last_ev = @cvm.add_event_before_event(ev, person, title)
				collectionView.insertItemsAtIndexPaths([path])
			end
			if img
				loc = @cvm.index_path_for_thing(@last_ev)
				cell = collectionView.cellForItemAtIndexPath(loc)
				snap_to img, cell.center
			end
		}
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
		# puts "redrawing at #{path.inspect}"
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

	def display_suggestions event, navigationController = nil
		uiWebView = push_webview(navigationController)
		with_street_address do |loc|
			url = Event.suggestions_url(event, loc)
			nsurl = NSURL.URLWithString(url)
			nsreq = NSURLRequest.requestWithURL(nsurl)
			uiWebView.loadRequest(nsreq)
		end
	end

	def was_modified(ev)
		reload
	end


end

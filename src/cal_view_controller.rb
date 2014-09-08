class DayHeaderReusableView < UICollectionReusableView; attr_accessor :section; end

class SandFlowLayout < UICollectionViewFlowLayout
	def prepareForCollectionViewUpdates(foo)
		super rescue nil  # ios 6.1 bug workaround
	end
end

class CalViewController < AMScrollingCollectionViewController
	include ViewControllerImprovements
	include CollectionViewControllerImprovements
	include BW::KVO

  
	############
	# lifecycle

	def viewDidLoad
		super

		navigationController.navigationBar.setTranslucent(false)
		# navigationController.navigationBar.setTitleVerticalPositionAdjustment(0, forBarMetrics: UIBarMetricsDefault)
		followScrollView(collectionView)

		# set up the screen
		# collectionView.contentInset = UIEdgeInsetsMake(26,0,50,0)  # top left bottom right
		collectionView.contentInset = UIEdgeInsetsMake(8,0,50,0)  # top left bottom right

		# about button
		navigationItem.rightBarButtonItem.setTarget(self)
		navigationItem.rightBarButtonItem.setAction(:about)
		hearts =  UIImageView.alloc.initWithImage(UIImage.imageNamed("3hearts"))
		navigationItem.leftBarButtonItem.customView = hearts
		# hearts.opaque = false
		# hearts.layer.opacity = 0.5
		# hearts.alpha = 0.5

		# navigationItem.titleView = hearts
		# frame.origin.x = 10;
		# hearts.frame = frame

		# button = UIButton.buttonWithType(UIButtonTypeRoundedRect)
		# button.addTarget(self, action: :about, forControlEvents:UIControlEventTouchDown)
		# button.setTitle("Settings", forState:UIControlStateNormal)
		# button.frame = CGRectMake(80.0, -75.0, 160.0, 30.0)  #xywh
		# collectionView.addSubview(button)

		# populate myself
		@cvm = CalViewModel.new
		collectionView.delegate = self
		collectionView.dataSource = self
		@cvm.load_events
		update_today_events_styles

		# add the reordering longpress gestures
		mgr = DragToReorder.new(view, collectionView, nil, self)
		addDragManager(mgr, UILongPressGestureRecognizer)

		# pull to refresh

		collectionView.addPullToRefreshWithActionHandler lambda{
			Event.event_store.refreshSourcesIfNecessary
    			collectionView.pullToRefreshView.stopAnimating
		}

		# recognize random single taps
		@stgr = UITapGestureRecognizer.alloc.initWithTarget(self, action: :singleTap)
		@stgr.numberOfTapsRequired = 1
		@stgr.delegate = self
		collectionView.addGestureRecognizer(@stgr)

		1.minute.every{ update_today_events_styles }
	end

	def gestureRecognizerShouldBegin(gr)
		return true unless gr == @stgr
		return false
	end

	def about
		@form = Formotion::Form.new({
		  sections: [{
		    title: "Settings",
		    rows: [{
		      title: "Sounds",
		      key: :sounds,
		      type: :switch,
		    }]
		  }, {
		  	title: "Info",
		  	rows: [
		  		{
			  		title: "How to Use",
			  		type: :subform,
			  		key: :use,
			  		subform: {
			  			sections: [{
				  			rows: [
								{
								  title: "How to play",
								  type: :web_view,
				  				  row_height: 300,
								  value: "Drag appointments up from the dock into the schedule to schedule things. Tap an appointment to see details. Hold to reschedule or delete."
								}
				  			]
				  		}]
		  			},
		  		},
		  		{
			  		title: "Credits",
			  		type: :subform,
			  		key: :use,
			  		subform: {
			  			sections: [{
				  			rows: [
				  				{
				  					# title: "Credits",
				  					type: :web_view,
				  					row_height: 300,
				  					value:
						  			"Sand is a calendar app by Joe Edelman, under arrangement with my former startup, Citizen Logistics."+
						  			"Thanks to Sarah Ismail for giving me some tea while I made this app."+
						  			"And extra special thanks to Tim Koelkebeck and Jordan Stout for talking with me about calendar interfaces for two years."
				  				},
								{
									# title: "Image Credits",
									type: :web_view,
									row_height: 300,
									value: "images by
<pre>
sunshine
http://www.flickr.com/photos/gigi62/3635592950/

exercise
http://www.flickr.com/photos/bass_nroll/
http://www.flickr.com/photos/bass_nroll/2212219500/

breakfast
http://www.flickr.com/photos/pinksherbet/
http://www.flickr.com/photos/pinksherbet/415651103/

lunch
http://www.flickr.com/photos/stuckincustoms/
http://www.flickr.com/photos/stuckincustoms/3526911857/

afternoon
http://www.flickr.com/photos/sukanto_debnath/
http://www.flickr.com/photos/sukanto_debnath/530073549

happy hour
http://www.flickr.com/photos/14646075@N03/
http://www.flickr.com/photos/14646075@N03/3069089312

quiet
http://www.flickr.com/photos/h-k-d/5996845093/
</pre>"
								}
				  			]
				  		}]
		  			}
		  		}
		  	]
		  }]
		})
		observe(@form.row(:sounds), :value) do |oldv, newv|
			NSLog "sounds #{newv.inspect}"
			NSUserDefaults['mute'] = !newv
		end
		@form_controller = Formotion::FormController.alloc.initWithForm(@form)
		display_controller_in_navcontroller @form_controller, navigationController
	end

	def singleTap
		case @stgr.state
		when UIGestureRecognizerStateEnded
          # unfocus
		end
	end

	def viewWillAppear(animated)
		super
		configure_animator
		on_notification("ReloadCalendar"){ |x| reload }
		collectionView.setContentOffset(CGPointMake(0.0, -20.0))
		# @ekobserver = App.notification_center.observe(EKEventStoreChangedNotification){ |x| reload }
	end

	def viewDidAppear(animated)
		super
		update_today_events_styles
	end

	def viewWillDisappear(animated)
		super
		# App.notification_center.unobserve @ekobserver if @ekobserver
	end

	def reload
  		@cvm.load_events
  		collectionView.reloadData
		update_today_events_styles
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
    	return unless Integer === s and s >= 0 and s < 15  # FIXME: hack for bug I don't understand
    	push_animation{
			@cvm.hover s
			positions = @cvm.placeholder_positions
			collectionView.insertItemsAtIndexPaths(positions)
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

    def animate_add_event(ev, before_event = nil, draggy_image = nil)
    	push_animation{
    		puts "aae: ev: #{ev.inspect}"

    		positions = @cvm.placeholder_positions
			if positions and positions.size > 0
		    	@cvm.hover nil
				collectionView.deleteItemsAtIndexPaths(positions)
			end

    		added_loc = @cvm.add_event(ev, before_event)
			collectionView.insertItemsAtIndexPaths([added_loc.nsindexpath])

	    	if draggy_image and loc = @cvm.index_path_for_thing(ev)
				cell = collectionView.cellForItemAtIndexPath(loc)
				snap_to draggy_image, cell.center
			end
    	}
    end

    def update_timer_label event, seconds_remaining
		loc = @cvm.index_path_for_thing(event)
		if cell = collectionView.cellForItemAtIndexPath(loc)
			cell.update_timer_label seconds_remaining
		end
    end

    def redraw(event)
    	p = @cvm.index_path_for_thing(event)
		collectionView.reloadItemsAtIndexPaths([p])
    end

	def animate_mv_and_close thing_was, placeholder, img = nil
		end_path = @cvm.index_path_for_thing(placeholder)
		case placeholder
		when Placeholder
			push_animation{
		    	# get the old location
				old_path = @cvm.index_path_for_event(thing_was)

				# and the starting placeholder positions
		    	positions = @cvm.placeholder_positions

				# reload the placeholder as an event
				@cvm.move_to_placeholder(thing_was, placeholder)
		    	@cvm.hover nil

				# delete all the placeholders except the one we replaced, plus the thing we deleted
				collectionView.deleteItemsAtIndexPaths(positions - [end_path] + [old_path])

				# reload the new placeholder
				collectionView.reloadItemsAtIndexPaths([end_path])

				if img
					loc = @cvm.index_path_for_thing(thing_was)
					cell = collectionView.cellForItemAtIndexPath(loc)
					snap_to img, cell.center
				end
			}
		else
			push_animation{
				# delete from old location and replace placeholder
				old_path = @cvm.index_path_for_event(thing_was)
				new_loc = @cvm.move_before_event(thing_was, placeholder)
				new_path = [end_path.section, new_loc].nsindexpath
				collectionView.deleteItemsAtIndexPaths([old_path])
				collectionView.insertItemsAtIndexPaths([new_path])
				update_today_events_styles

				if img
					loc = @cvm.index_path_for_thing(thing_was)
					cell = collectionView.cellForItemAtIndexPath(loc)
					snap_to img, cell.center
				end
			}
			animate_close
		end
	end

	def after_animations
		super
		update_today_events_styles
	end

	def scrollViewDidScroll(sv)
		update_today_events_styles
	end

	def scrollViewWillBeginDragging(sv)
      # unfocus
	end

	def update_today_events_styles
		prev = nil
		@cvm && @cvm.today_paths.each do |path|
			cell = collectionView.cellForItemAtIndexPath(path)
			prev = cell && cell.update_time_of_day(prev)
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
		else
			cb.call(nil, text)
		end
	end

	def display_friend_record ev, navigationController = nil
		return unless abrecord = ev.person_abrecord
		display_person navigationController, abrecord
	end


	##############
	# wiring

	def collectionView(cv, shouldSelectItemAtIndexPath:path)
		return true if !@selected_path or !path.eql?(@selected_path)
		doneEditing
		@selected_path = nil
		false
	end

	def collectionView(cv, didSelectItemAtIndexPath:path)
		@selected_path = path
		thing = @cvm.thing_at_index_path path
		view_event(thing) if EKEvent === thing
	end

	def drag_up_from_dock_enabled?
      return false
	end

	def drag_to_reorder_enabled?
      return true
	end

	def doneEditing
		collectionView.deselectItemAtIndexPath(@selected_path, animated:true)
		@selected_path = nil
	end

	def view_event ev
		return false unless ev
		@selected_path = @cvm.index_path_for_thing(ev)
		@selected_path && collectionView.selectItemAtIndexPath(@selected_path, animated:true, scrollPosition: UICollectionViewScrollPositionNone)
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
			cell.as_placeholder(ev)
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
		DockItem.with_suggestions_url(event){ |url| set_webview_url(url) }
	end

	def was_modified(ev)
		reload
	end


end

module ViewControllerImprovements

	def configure_animator
		if Kernel.const_defined? "UIDynamicAnimator"
			@animator = UIDynamicAnimator.alloc.initWithReferenceView(view.window)
			@animator.delegate = self
		end
	end


	def apply_gravity view, g = 0.3
		return view.removeFromSuperview() unless @animator
		@animated_view = view
		g = UIGravityBehavior.alloc.initWithItems [view]
		g.magnitude = 1.0
		p = UIPushBehavior.alloc.initWithItems([view], mode: UIPushBehaviorModeInstantaneous)
		p.setAngle(1.7, magnitude: 2.0)
		p.active = true
		p.setTargetOffsetFromCenter(UIOffsetMake(20,20), forItem: view)
		@animator.addBehavior g
		@animator.addBehavior p
	end

	def snap_to view, point
		return view.removeFromSuperview() unless @animator
		pt = collectionView.convertPoint(point, toView: view.window)
		@animated_view = view
		@animator.addBehavior UISnapBehavior.alloc.initWithItem(view, snapToPoint: pt)
		view.fade_out delay: 0.3
	end

	def dynamicAnimatorDidPause(animator = nil)
		@animated_view && @animated_view.removeFromSuperview()
		@animator.removeAllBehaviors
	end

	def dynamicAnimatorDidResume(animator = nil)
		# @animated_view && @animated_view.removeFromSuperview()
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

	def after_animations
		update_map
	end

	def run_animations
		@animations_running = true
		layer = collectionView.viewForBaselineLayout.layer
		@baseline_animation_speed = layer.speed
		collectionView.performBatchUpdates(@animation_stack.shift, completion: lambda{ |x|
			if @animation_stack.empty?
				@animations_running = false
				after_animations
				layer.setSpeed @baseline_animation_speed
			else
				run_animations
			end
		})
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

	def push_webview nc = nil
		bounds = UIScreen.mainScreen.bounds
		rect = CGRectMake(0, 0, bounds.width, bounds.height);

    	@uiWebView = UIWebView.alloc.initWithFrame(rect)
    	@uiWebView.delegate = self
    	
		vc = UIViewController.alloc.init
    	vc.view.addSubview(@uiWebView)
		display_controller_in_navcontroller(vc, nc)
		return @uiWebView
	end

	def go_to_url nc = nil, url
		@recent_url = url
		@uiWebView = push_webview(nc)
		reload_webview
	end

	def webView(wv, didFailLoadWithError: err)
		return if err.code == NSURLErrorCancelled
		return dismissViewController unless @recent_url
        UI.confirm "Load failed", "Retry?", "Yeah" do |yes|
        	yes ? reload_webview : dismissViewController
        end
	end

	def set_webview_url url
		@recent_url = url
		reload_webview
	end

	def reload_webview
		nsurl = NSURL.URLWithString(@recent_url)
		nsreq = nsurl && NSURLRequest.requestWithURL(nsurl)
		return UI.alert('Bad URL', "Can't load: #{@recent_url}") unless nsreq
		@uiWebView.loadRequest(nsreq)
	end

	def display_person nc = nil, ab_person
		v = ABPersonViewController.alloc.init
		v.personViewDelegate = self
		v.displayedPerson = ab_person
		display_controller_in_navcontroller(v, nc)
	end

	def menu *args, &cb
		UI.menu *args, &cb
	end

	def observe msg, &cb
		@observers ||= []
		@observers << App.notification_center.observe(msg, &cb)
	end

	def viewWillDisappear(animated = nil)
		super
		@observers && @observers.each{ |o| App.notification_center.unobserve o }
	end

end

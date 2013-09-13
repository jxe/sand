class AppDelegate
  attr_accessor :window

  def configure_menus(vcs)
  	items = []
  	vcs.each do |title, vc|
  		items.push RESideMenuItem.alloc.initWithTitle(title, action: proc{ |menu, item|
			menu.hide
		    menu.displayContentController(vc)
		})
  	end

	_sideMenu = RESideMenu.alloc.initWithItems(items)
	_sideMenu.hide
    _sideMenu.displayContentController(vcs[0][1])
    _sideMenu
  end

  def application(application, didFinishLaunchingWithOptions:launchOptions)
  	s = UIStoryboard.storyboardWithName("MainStoryboard", bundle:nil)
  	home_vc = s.instantiateInitialViewController
  	about_vc = s.instantiateViewControllerWithIdentifier('About')

	self.window = UIWindow.alloc.initWithFrame(UIScreen.mainScreen.bounds)
	window.rootViewController = configure_menus([
		['Hourglass', home_vc],
		['Pause Life', about_vc]
	])
	window.makeKeyAndVisible

	unless AuthenticationController.both_authed?
		auth_controller = s.instantiateViewControllerWithIdentifier('Auth')
		window.rootViewController.presentModalViewController(auth_controller, animated: false)
	end

	true
  end

end

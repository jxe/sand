class AppDelegate
	attr_accessor :window

  def application(application, didFinishLaunchingWithOptions:launchOptions)
  	s = UIStoryboard.storyboardWithName("MainStoryboard", bundle:nil)
  	home_vc = s.instantiateInitialViewController

	homeItem = RESideMenuItem.alloc.initWithTitle('Hourglass', action: proc{ |menu, item|
		menu.hide
	    menu.displayContentController(home_vc)
	})

	pauseItem = RESideMenuItem.alloc.initWithTitle('Pause Life', action: proc{ |menu, item|
		menu.hide
	    menu.displayContentController(s.instantiateViewControllerWithIdentifier('About'))
	})

	_sideMenu = RESideMenu.alloc.initWithItems([homeItem, pauseItem])
	_sideMenu.hide
    _sideMenu.displayContentController(home_vc)
	self.window = UIWindow.alloc.initWithFrame(UIScreen.mainScreen.bounds)
	window.rootViewController = _sideMenu
	window.makeKeyAndVisible
	true
  end

end

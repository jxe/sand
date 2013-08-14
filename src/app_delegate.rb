class AppDelegate
	attr_accessor :window

  def application(application, didFinishLaunchingWithOptions:launchOptions)
  	s = UIStoryboard.storyboardWithName("MainStoryboard", bundle:nil)
  	vc = s.instantiateInitialViewController
  	puts "#{vc.inspect}"
		homeItem = RESideMenuItem.alloc.initWithTitle('Home', action: proc{ |menu, item|
			menu.hide
		    menu.displayContentController(vc)
		})
		_sideMenu = RESideMenu.alloc.initWithItems([homeItem])
		_sideMenu.hide
	    _sideMenu.displayContentController(vc)
		self.window = UIWindow.alloc.initWithFrame(UIScreen.mainScreen.bounds)
		window.rootViewController = _sideMenu
		window.makeKeyAndVisible
		true
  end

end

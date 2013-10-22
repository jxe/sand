class AppDelegate
  include MotionDataWrapper::Delegate
  attr_accessor :window

  def configure_menus(vcs)
    items = []
    @vcs = vcs
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

   self.window = UIWindow.alloc.initWithFrame(UIScreen.mainScreen.bounds)
   window.rootViewController = configure_menus([
    ['Calendar', s.instantiateInitialViewController],
    ['Tutorial', s.instantiateViewControllerWithIdentifier('Tutorial')],
    ['Thanks', s.instantiateViewControllerWithIdentifier('Thanks')]
   ])
   window.makeKeyAndVisible

   unless AuthenticationController.all_authed?
    auth_controller = s.instantiateViewControllerWithIdentifier('Auth')
    window.rootViewController.presentModalViewController(auth_controller, animated: false)
   end

   true
  end

  def applicationDidBecomeActive(application)
    # We need to properly handle activation of the application with regards to SSO
    # (e.g., returning from iOS 6.0 authorization dialog or from fast app switching).
    FBSession.activeSession.handleDidBecomeActive
  end

  def applicationWillTerminate(application)
    # Kill the Facebook session when the application terminates
    FBSession.activeSession.close
  end

  def applicationSignificantTimeChange(application)
    @vcs && @vcs[0][1].reload
  end

end

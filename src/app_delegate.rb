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
    # super
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

  def application(app, willFinishLaunchingWithOptions: options)
    true
  end

  def application(application, openURL: url, sourceApplication: from_app, annotation: blah)
    process_sand_url url
    FBSession.activeSession.handleOpenURL(url)
    true
  end

  def process_sand_url url, webViewParent = nil
    case spec = url.resourceSpecifier
    when /^reset-dock$/
      webViewParent.dismissViewController if webViewParent
      UI.confirm "Reset Dock", "Reset Dock to Factory Defaults?", "Engage" do |yes|
        DockItem.load_defaults if yes
      end

    when /^dockitem\?(.*)$/
      begin
        DockItem.install($1.URLQueryParameters)
      rescue Exception => e
        BW::UIAlertView.default(:title => e.message)
      end
      webViewParent.dismissViewController if webViewParent
    else
      BW::UIAlertView.default(:title => "Unrecognized sandapp: URL")
    end
  end

end

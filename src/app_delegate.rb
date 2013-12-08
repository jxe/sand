class AppDelegate
  include MotionDataWrapper::Delegate
  attr_accessor :window

  def application(application, didFinishLaunchingWithOptions:launchOptions)
    # NSLog "%@", "App running!"
    Crittercism.enableWithAppID("527bdb3dd0d8f74cd4000003")

    s = UIStoryboard.storyboardWithName("MainStoryboard", bundle:nil)

    self.window = UIWindow.alloc.initWithFrame(UIScreen.mainScreen.bounds)
    window.rootViewController = s.instantiateInitialViewController;
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
      data = $1.URLQueryParameters
      webViewParent.dismissViewController if webViewParent
      SVProgressHUD.show
      Dispatch::Queue.concurrent.async do 
        begin
          DockItem.install(data)
        rescue Exception => e
          Dispatch::Queue.main.async{
            SVProgressHUD.dismiss rescue nil
            BW::UIAlertView.default(:title => e.message)
          }
        ensure
          Dispatch::Queue.main.async{ SVProgressHUD.dismiss rescue nil }
        end
      end

    else
      BW::UIAlertView.default(:title => "Unrecognized sandapp: URL")

    end
  end

end

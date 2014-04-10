class AppDelegate
  include MotionDataWrapper::Delegate
  attr_accessor :window

  def application(application, didFinishLaunchingWithOptions:launchOptions)
    # NSLog "%@", "App running!"
    Crittercism.enableWithAppID("527bdb3dd0d8f74cd4000003") unless Device.simulator?

    s = UIStoryboard.storyboardWithName("MainStoryboard", bundle:nil)

    self.window = UIWindow.alloc.initWithFrame(UIScreen.mainScreen.bounds)
    window.rootViewController = s.instantiateInitialViewController;
    window.makeKeyAndVisible

    # FBSession.activeSession.closeAndClearTokenInformation
    # FBSession.activeSession = nil
    # FBSession.setActiveSession(nil)

    if AuthenticationController.all_authed?
        # FBSession.renewSystemCredentials(proc{ |result, error|
        #   if error
        #     NSLog("error renewing: #{error.inspect} #{result.inspect}")
        #     return
        #   end
        #   NSLog("result: #{result.inspect}")
        #   FBSession.openActiveSessionWithReadPermissions(nil, allowLoginUI:true, 
        #                         completionHandler:lambda{ |session, state, error| 
        #                               if error
        #                                   NSLog("FB errr: #{FBErrorUtility.userMessageForError(error)}")
        #                               end
        #                         }
        #   )
        # })

        FBSession.openActiveSessionWithAllowLoginUI(true)

    else
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
    process_desires_url url
    FBSession.activeSession.handleOpenURL(url)
    true
  end

  def application(app, didReceiveLocalNotification: notification)
    AudioServicesPlayAlertSound(KSystemSoundID_Vibrate)
  end

  def process_desires_url url, webViewParent = nil
    data = url.query.URLQueryParameters
    NSLog data.inspect
    if data['soon'] == 'none'
      webViewParent.dismissViewController if webViewParent
      UI.confirm "Reset Dock", "Reset Dock to Factory Defaults?", "Engage" do |yes|
        DockItem.load_defaults if yes
      end
    elsif data['soon']
      json = data['soon'].dataUsingEncoding(NSUTF8StringEncoding)
      NSLog BW::JSON.parse(json).inspect
      webViewParent.dismissViewController if webViewParent
      SVProgressHUD.show
      Dispatch::Queue.concurrent.async do 
        begin
          DockItem.install(BW::JSON.parse(json))
        rescue Exception => e
          Dispatch::Queue.main.async{
            SVProgressHUD.dismiss rescue nil
            BW::UIAlertView.default(:title => e.inspect)
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

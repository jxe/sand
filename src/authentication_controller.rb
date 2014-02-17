class AuthenticationController < UIViewController
	def button_pressed
		please_authenticate_all_with_callback do
			DockItem.load_defaults
			dismissViewControllerAnimated(true, completion: nil)
			App.notification_center.post "ReloadCalendar"

			# App.notification_center.postNotificationName(EKEventStoreChangedNotification, object: self)
		end
	end

	def please_authenticate_all_with_callback(&cb)
		NSLog "please_authenticate_all_with_callback"
		cb.call if cal_authed? and contacts_authed? and fb_authed?
		@on_all_authenticated = cb
		prompt_for_cal_auth unless cal_authed?
		prompt_for_contacts_auth unless contacts_authed?
		prompt_for_fb_auth unless fb_authed?
	end

	def prompt_for_cal_auth
		NSLog "prompt_for_cal_auth"
		@event_store ||= EKEventStore.alloc.init
		@event_store.requestAccessToEntityType(EKEntityTypeEvent, completion: proc{ |granted, error|
			cal_authed! if granted
		})
	end

	def prompt_for_contacts_auth
		NSLog "prompt_for_contacts_auth"
		AddressBook.request_authorization{ |authed| contacts_authed! }
	end

	def prompt_for_fb_auth
		NSLog "prompt_for_fb_auth"
    	FBSession.openActiveSessionWithReadPermissions(%w{user_events friends_events}, allowLoginUI: true, completionHandler: Proc.new do |session, state, error|
      		if state == FBSessionStateOpen and !error
      			fb_authed!
      		else
				BW::UIAlertView.default(:title => "Twiddle your facebook settings!").show
      		end
    	end)
	end

	def self.all_authed?
		NSUserDefaults['cal_authed'] and NSUserDefaults['contacts_authed'] and NSUserDefaults['fb_authed']
	end

	def cal_authed?
		NSUserDefaults['cal_authed']
	end

	def fb_authed?
		NSUserDefaults['fb_authed']
	end

	def contacts_authed?
		NSUserDefaults['contacts_authed']
	end

	def cal_authed!
		NSUserDefaults['cal_authed'] = true
		check_if_all_authed
	end

	def fb_authed!
		NSUserDefaults['fb_authed'] = true
		check_if_all_authed
	end

	def contacts_authed!
		NSUserDefaults['contacts_authed'] = true
		check_if_all_authed
	end

	def check_if_all_authed		
		Dispatch::Queue.main.async{ @on_all_authenticated.call } if cal_authed? and contacts_authed? and fb_authed? and @on_all_authenticated
	end
end

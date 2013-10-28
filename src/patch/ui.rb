module UI

	def self.menu options, canceled = nil, &cb
		UIActionSheet.alert nil, buttons: ['Cancel', nil, *options], success: proc{ |thing|
			cb.call(thing) unless thing == 'Cancel' or thing == :Cancel
		}, cancel: proc{
			canceled.call() if canceled
		}
	end

	def self.confirm title, msg, action, &cb
		BW::UIAlertView.default({
		  :title               => title,
		  :message             => msg,
		  :buttons             => ["Cancel", action],
		  :cancel_button_index => 0
		}) do |alert|
			cb.call(alert.clicked_button.cancel? ? false : true)
		end.show
	end

end

class DockItem < MotionDataWrapper::Model

	# sandapp:dockitem?title=band+practice&image_url=http://example.com/band-practice.jpg

	def self.visible
		ensure_loaded
		all.select{ |x| !x.is_hidden}
	end

	def self.install(data)
		puts "data: #{data.inspect}"

		raise "No title" unless data['title']
		raise "No image" unless data['image_url']

		if data["image_url"] and !data['image']
			data['image'] = NSData.dataWithContentsOfURL(NSURL.URLWithString(data["image_url"]))
		end

		data['regex'] ||= data['title']
		data['suggestions_desc'] ||= "Suggestions for #{data['title']}"
		data['suggestions_url']  ||= "http://www.yelp.com/search?find_desc=#{data['title'].sub(' ', '+')}&find_loc=%%"

		item = if prev = find_by_title(data['title'])
			data.each{ |k,v| prev.send("#{k}=", v) }
			prev.save
			prev
		else
			create(data)
		end
		Dispatch::Queue.concurrent.async{
			sleep 0.1
			Dispatch::Queue.main.async{
				App.notification_center.post 'ReloadDock'
			}
		}
		item
	end

	# TODO: match by time of day, match default
	def self.matching(ev)
		ensure_loaded
		match_by_regex = all.detect{ |x| ev.title =~ /#{x.regex}/ }
		return match_by_regex if match_by_regex
		time_of_day = ev.startDate.longer_time_of_day_label
		match_by_time = all.detect{ |x| time_of_day == x.regex[1..-1] }
		return match_by_time if match_by_time
		return find_by_regex('DEFAULT')
	end

	def hide!
		self.is_hidden = true
		save
	end

	def self.suggestion_descriptor(ev)
		matching(ev).suggestions_descriptor(ev)
	end

	def self.raw_suggestions_url(ev)
		# time_label = ev.startDate.time_of_day_label
		url = matching(ev).suggestions_url
		url.sub("%T", ev.title.gsub(' ', '%20'))
	end

	def suggestions_descriptor(ev)
		return unless ev.title
		raw = suggestions_desc || "%T"
		raw.sub("%T", ev.title)
	end

	def self.image(ev)
		(m = matching(ev)) && m.uiimage
	end

	def event_at(placeholder)
		Event.add_event(placeholder.startDate, nil, title)
	end

	def matcher_type
		case regex
		when "DEFAULT"; :default
		when /^@/; :timing
		else :regex
		end
	end

	def uiimage
		return UIImage.alloc.initWithData(image) if image

		case image_url
		when /^http/
			data = NSData.dataWithContentsOfURL(NSURL.URLWithString(image_url))
			UIImage.alloc.initWithData(data)
		else
			UIImage.imageNamed(image_url)
		end
	end

	def self.ensure_loaded
		empty? and load_defaults
	end

	def self.load_defaults
		all.each(&:destroy)
		DEFAULT_DOCK_ITEMS.each{ |item| create(item) }
		Dispatch::Queue.main.async{
			sleep 0.1
			App.notification_center.post 'ReloadDock'
		}
	end

	def self.suggestions_url(ev, loc)
		# loc = loc.stringByAddingPercentEscapesUsingEncoding(NSUTF8StringEncoding)
		# loc2 = CFURLCreateStringByAddingPercentEscapes(nil, loc, nil, "!*'();:@&=+$,/?%#[]", KCFStringEncodingUTF8)
		loc2 = loc.gsub("\n"," ").sub(" United States", "").gsub(/\u200E|\s|\+/, '%20').gsub(/(\d+)\-(\d+)/, "\\1")
		raw = raw_suggestions_url(ev)
		url = raw.sub("%%", loc2.strip)
		NSLog "%@", "URL: #{url}"
		url
	end


	def fresh_event_at(startTime)
	end

	def configure_event(event, &cb)
	end

end

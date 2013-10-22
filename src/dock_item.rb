class DockItem < MotionDataWrapper::Model

	# sandapp:dockitem?title=band+practice&image_url=http://example.com/band-practice.jpg

	def self.visible
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

		create(data)
	end

	# TODO: match by time of day, match default
	def self.matching(ev)
		all.detect{ |x| ev.title =~ /#{x.regex}/ } || find_by_regex('DEFAULT')
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
		url.sub("%T", ev.title.sub(' ', '%20'))
	end

	def suggestions_descriptor(ev)
		raw = suggestions_desc || "%T"
		raw.sub("%T", ev.title)
	end

	def self.image(ev)
		(m = matching(ev)) && m.uiimage
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

	def self.load_defaults
		DEFAULT_DOCK_ITEMS.each{ |item| create(item) }
	end

	def self.suggestions_url(ev, loc)
		# loc = loc.stringByAddingPercentEscapesUsingEncoding(NSUTF8StringEncoding)
		# loc2 = CFURLCreateStringByAddingPercentEscapes(nil, loc, nil, "!*'();:@&=+$,/?%#[]", KCFStringEncodingUTF8)
		loc2 = loc.gsub("\n"," ").sub(" United States", "").gsub(/\u200E|\s/, '%20')
		raw = raw_suggestions_url(ev)
		url = raw.sub("%%", loc2.strip)
		NSLog "%@", "URL: #{url}"
		url
	end



end

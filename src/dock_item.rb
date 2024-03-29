class DockItem < MotionDataWrapper::Model

	# sandapp:dockitem?title=band+practice&image_url=http://example.com/band-practice.jpg

	def self.all_cached
		@all ||= all
	end

	def self.reset_cache
		@all = nil
	end

	def self.visible
		ensure_loaded
		all_cached.select{ |x| !x.is_hidden or x.is_hidden == 0 }.sort_by{ |x| x.dock_position || -1 }
	end

	def self.move(i,j)
		vis = visible
		obj = vis.delete_at(i)
		vis.insert(j, obj)
		vis.compact.each_with_index do |o, i|
			o.dock_position = i
			o.save
		end
		reset_cache
	end

	def self.install(data)
		puts "data: #{data.inspect}"
		data.each do |k,v|
			raise "No image" unless v['image']
			v['title'] = k
			v['regex'] ||= k

			NSLog 'fetching image'
			v['image'] = NSData.dataWithContentsOfURL(NSURL.URLWithString(v["image"]))
			NSLog 'got image'
			NSLog '%@', v.inspect

			NSLog 'setting up links'
			v['link'] = v['links'].first if v['links']
			if v['link']
				v['suggestions_desc'] = v['link'].keys.first
				v['suggestions_url'] = v['link'].values.first
			end
			NSLog 'set up links'
			NSLog '%@', v.inspect

			v['suggestions_desc'] ||= "Suggestions for #{k}"
			v['suggestions_url']  ||= "http://www.yelp.com/search?find_desc=#{k.sub(' ', '+')}&find_loc=%%"

			v.delete('links')
			v.delete('link')

			NSLog '%@', v.inspect
			if prev = find_by_title(k)
				v.each{ |k,v| prev.send("#{k}=", v) }
				prev.is_hidden = false
				prev.save
				NSLog 'saved'
			else
				create(v)
				NSLog 'created'
			end
		end
	
		reset_cache
		Dispatch::Queue.concurrent.async{
			sleep 0.1
			Dispatch::Queue.main.async{ App.notification_center.post 'ReloadDock'}
		}
	end

	# TODO: match by time of day, match default
	def self.matching(ev)
		ensure_loaded
		match_by_regex = all_cached.detect{ |x| ev.title =~ /#{x.regex}/ }
		return match_by_regex if match_by_regex
		# time_of_day = ev.startDate.longer_time_of_day_label
		# match_by_time = all_cached.detect{ |x| time_of_day == x.regex[1..-1] }
		# return match_by_time if match_by_time
		return all_cached.detect{ |x| x.regex == 'DEFAULT' }
	end

	def hide!
		self.is_hidden = true
		save
		self.class.reset_cache
	end

	def self.suggestion_descriptor(ev)
		matching(ev).suggestions_descriptor(ev)
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
		ev = Event.add_event(placeholder.startDate, nil, title)
		BW::HTTP.post(ping_url, payload: {did: 'scheduled', at: placeholder.startDate}) if ping_url
		ev
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
		reset_cache
		Dispatch::Queue.main.async{
			sleep 0.1
			App.notification_center.post 'ReloadDock'
		}
	end



	def self.with_suggestions_url(event, &blk)
		matching(event).with_suggestions_url(event, &blk)
	end

	def with_suggestions_url(event, &blk)
		raw = suggestions_url.sub("%T", event.title.gsub(' ', '%20'))
		if raw =~ /%%/
			with_street_address do |loc|
				loc2 = loc.gsub("\n"," ").sub(" United States", "").gsub(/\b(\d+)\D(\d+)\b/, "\\1").gsub(/\u200E|\s|\+/, '%20')
				url = raw.sub("%%", loc2.strip)
				blk.call(url)
			end
		else
			blk.call(raw)
		end
	end


	# location stuff

	@@cached_location = nil
	@@cached_geocodes = {}

	def with_location &blk
		blk.call(@@cached_location) if @@cached_location
		AKLocationManager.distanceFilterAccuracy = KCLLocationAccuracyKilometer
		AKLocationManager.startLocatingWithUpdateBlock(proc{ |result|
			blk.call(@@cached_location = result)
			AKLocationManager.stopLocating
		}, failedBlock: proc{ |error|
			blk.call(@@cached_location = nil)
			AKLocationManager.stopLocating
		})
	end

	def with_street_address &blk
		with_location{ |loc| loc ? reverse_geocode(loc){ |addr| blk.call(addr) } : blk.call("nowhere") }
	end

	def reverse_geocode loc, &blk
		close = @@cached_geocodes.keys.select{ |l| l.distanceFromLocation(loc) < 1000 }
		if not close.empty?
			blk.call(@@cached_geocodes[close.first])
		else
			@@coder ||= CLGeocoder.alloc.init
			@@coder.reverseGeocodeLocation(loc, completionHandler:lambda{
				|placemarks, error|
				if !error && placemarks[0]
					addr = ABCreateStringWithAddressDictionary(placemarks[0].addressDictionary, false)
					@@cached_geocodes[loc] = addr
					blk.call(addr)
				end
			})
		end
	end



	# loc = loc.stringByAddingPercentEscapesUsingEncoding(NSUTF8StringEncoding)
	# loc2 = CFURLCreateStringByAddingPercentEscapes(nil, loc, nil, "!*'();:@&=+$,/?%#[]", KCFStringEncodingUTF8)
	# NSLog "%@", "URL: #{url}"


	def fresh_event_at(startTime)
	end

	def configure_event(event, &cb)
	end

end

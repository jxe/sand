module CollectionViewControllerImprovements

	attr_reader :animations_running, :section_map

	def reveal_section s
		last_section = collectionView.numberOfSections - 1
		screen_top = collectionView.contentOffset.y.to_i + 40  # for the status bar
		screen_height = collectionView.frame.height.to_i  # for the dock
		screen_bottom = screen_top + screen_height - 50
		section_top = top_of_header_for_section(s)
		section_bottom = if s == last_section
			section_top + 40
		else
			top_of_header_for_section(s+1)
		end
		return unless section_top and section_bottom

		if screen_bottom < section_bottom
			# scroll down
			pos = CGPointMake(0, section_bottom - screen_height + 50)
			collectionView.setContentOffset(pos, animated: true)
		elsif screen_top > section_top
			# scroll up
			pos = CGPointMake(0, section_top - 40)
			collectionView.setContentOffset(pos, animated: true)
		end
	end

	def scrollViewDidEndScrollingAnimation(cv)
		after_animations
	end

	def top_of_header_for_section i
		collectionView.layoutAttributesForSupplementaryElementOfKind(UICollectionElementKindSectionHeader, atIndexPath: [i].nsindexpath).frame.origin.y
	end

	def onscreen_section_map
		top = collectionView.contentOffset.y.to_i
		bottom = top + collectionView.frame.height.to_i
		map = {}
		next_section = 0
		last_section = collectionView.numberOfSections - 1

		(top..bottom).each do |y|
			next_section += 1 if next_section <= last_section and top_of_header_for_section(next_section) <= y
			map[y] = next_section - 1
		end

		uicollectionview_bugfix(map[top], map[bottom])

		map
	end

	def uicollectionview_bugfix(first, last)
		@section_cells ||= {}
		collectionView.subviews.each do |v|
			if DayHeaderReusableView === v
				v.removeFromSuperview unless v == @section_cells[v.section]
			end
		end
	end

	def update_map
		@section_map = onscreen_section_map
	end

	def addDragManager(mgr, *grArgs)
		(@dragManagers ||= []) << mgr
		view.addGestureRecognizer(mgr.newGestureRecognizer(*grArgs))
	end

end

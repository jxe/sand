class PlaceholderCell < UICollectionViewCell
	def initWithCoder(c)
		super
		self
	end

	def as_placeholder(time_of_day)
		# imageview = contentView.viewWithTag(100)
		personlabel = contentView.viewWithTag(102)

		# imageview.image  =  UIImage.imageNamed('q.png')
		personlabel.text = time_of_day
	end
end

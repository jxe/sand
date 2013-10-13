class AppointmentCell < UICollectionViewCell
	def initWithCoder(c)
		super
		pl = contentView.viewWithTag(112).layer
		l = CALayer.layer
		l.contents = UIImage.imageNamed('blackrect.png').CGImage
		l.frame = CGRectMake(-6,-12,85,90)
		pl.insertSublayer(l, atIndex:0)
		self
	end
end

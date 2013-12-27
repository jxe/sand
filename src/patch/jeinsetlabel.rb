class JEInsetLabel < UILabel

	def drawTextInRect(rect)
    	super(UIEdgeInsetsInsetRect(rect, UIEdgeInsetsMake(0, 5, 0, 5)))
    end

end

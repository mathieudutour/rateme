import UIKit

@objc open class RateBulletinItem: ActionBulletinItem {
    
    // MARK: Initialization
    
    override init() {
        title = "Rate"
    }
    
    // MARK: - Page Contents
    
    /// The title of the page.
    @objc public var title: String
    
    var userToRate: BLEUser? {
        didSet {
            title = "Rate " + (userToRate?.record?["username"] as? String ?? "")
        }
    }
    
    // MARK: - View Management
    
    public private(set) var titleLabel: UILabel!
    var starRating: StarRating!
    
    /**
     * Creates the content views of the page.
     *
     * It creates the standard elements and appends the additional customized elements returned by the
     * `viewsUnder` hooks.
     */
    
    public final override func makeContentViews(interfaceBuilder: BulletinInterfaceBuilder) -> [UIView] {
        
        var contentViews = [UIView]()
        
        
        // Title Label
        
        titleLabel = interfaceBuilder.makeTitleLabel()
        titleLabel.text = title
        
        contentViews.append(titleLabel)
        
        // Rating
            
        starRating = interfaceBuilder.makeRatingView()
        contentViews.append(starRating!)
        
        return contentViews
    }
    
}


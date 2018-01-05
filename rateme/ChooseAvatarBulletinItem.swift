import UIKit

/**
 * A standard bulletin item with a title and optional additional informations. It can display a large
 * action button and a smaller button for alternative options.
 *
 * - If you need to display custom elements with the standard buttons, subclass `PageBulletinItem` and
 * implement the `makeArrangedSubviews` method to return the elements to display above the buttons.
 *
 * You can also override this class to customize button tap handling. Override the `actionButtonTapped(sender:)`
 * and `alternativeButtonTapped(sender:)` methods to handle tap events. Make sure to call `super` in your
 * implementations if you do.
 *
 * Use the `appearance` property to customize the appearance of the page. If you want to use a different interface
 * builder type, change the `InterfaceBuilderType` property.
 */

@objc open class ChooseAvatarBulletinItem: ActionBulletinItem {
    
    // MARK: Initialization
    
    /**
     * Creates a bulletin page with the specified title.
     * - parameter title: The title of the page.
     */
    
    @objc public init(title: String) {
        self.title = title
    }
    
    @available(*, unavailable, message: "ChooseAvatarBulletinItem.init is unavailable. Use init(title:) instead.")
    override init() {
        fatalError("ChooseAvatarBulletinItem.init is unavailable. Use init(title:) instead.")
    }
    
    // MARK: - Page Contents
    
    /// The title of the page.
    @objc public var title: String
    
    /**
     * An description text to display below the image.
     *
     * If you set this property to `nil`, no label will be displayed (this is the default).
     */
    
    @objc public var descriptionText: String?
    
    var image: UIImage? {
        didSet {
            if (imageView != nil) {
                imageView?.image = image
            }
        }
    }
    
    /**
     * The code to execute when the image button is tapped.
     */
    
    @objc public var imageHandler: ((ChooseAvatarBulletinItem) -> Void)? = nil
    
    @objc open func imageTapped() {
        imageHandler?(self)
    }
    
    // MARK: - View Management
    
    public private(set) var titleLabel: UILabel!
    public private(set) var descriptionLabel: UILabel?
    public private(set) var imageView: UIImageView?
    
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
        
        // Description Label
        
        if let descriptionText = self.descriptionText {
            
            descriptionLabel = interfaceBuilder.makeDescriptionLabel()
            descriptionLabel!.text = descriptionText
            contentViews.append(descriptionLabel!)
            
        }
        
        let imageView = UIImageView(frame: CGRect(x: UIScreen.main.bounds.width / 2 - 50 - 32, y: 0, width: 100, height: 100))
        if (image != nil) {
            imageView.image = image
        }
        imageView.contentMode = .scaleAspectFill
        imageView.layer.cornerRadius = 50
        imageView.layer.borderColor = PURPLE.cgColor
        imageView.layer.borderWidth = 1.0
        imageView.clipsToBounds = true
        
        imageView.heightAnchor.constraint(equalToConstant: 100).isActive = true
        imageView.widthAnchor.constraint(equalToConstant: 100).isActive = true
        
        self.imageView = imageView
        
        let imageViewWrapper = UIView()
        imageViewWrapper.heightAnchor.constraint(equalToConstant: 100).isActive = true
        imageViewWrapper.addSubview(imageView)
        
        let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(imageTapped))
        imageView.isUserInteractionEnabled = true
        imageView.addGestureRecognizer(tapRecognizer)

        contentViews.append(imageViewWrapper)
        
        return contentViews
    }
    
}


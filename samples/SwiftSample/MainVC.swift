/*
 * Licensed Materials - Property of IBM
 *
 * 5725E28, 5725I03
 *
 * © Copyright IBM Corp. 2015, 2017
 * US Government Users Restricted Rights - Use, duplication or disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
 */


import UIKit

class MainVC : UITableViewController, UIViewControllerPreviewingDelegate
{
    @IBOutlet weak var version: UILabel?
    var previewingContext: UIViewControllerPreviewing?
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        version!.text = MCESdk.sharedInstance().sdkVersion()
        if #available(iOS 9.0, *) {
            self.previewingContext = self.registerForPreviewing(with: self, sourceView: self.view)
        }
    }
    
    @available(iOS 9.0, *)
    func isForceTouchAvailable() -> Bool
    {
        if self.traitCollection.responds(to: #selector(getter: UITraitCollection.forceTouchCapability))
        {
            return self.traitCollection.forceTouchCapability == UIForceTouchCapability.available
        }
        return false
    }
    
    func previewingContext(_ previewingContext: UIViewControllerPreviewing, commit viewControllerToCommit: UIViewController) {
        self.navigationController?.pushViewController(viewControllerToCommit, animated: true)
    }
    
    @available(iOS 9.0, *)
    func previewingContext(_ previewingContext: UIViewControllerPreviewing, viewControllerForLocation location: CGPoint) -> UIViewController? {
        let cellPosition = self.tableView.convert(location, from: self.view)
        if let path = self.tableView.indexPathForRow(at: cellPosition)
        {
            if let tableCell = self.tableView.cellForRow(at: path)
            {
                let storyboard = UIStoryboard.init(name: "Main", bundle: nil)
                if let ident = tableCell.restorationIdentifier
                {
                    let previewController = storyboard.instantiateViewController(withIdentifier: ident)
                    previewingContext.sourceRect = self.view.convert(tableCell.frame, from: self.tableView)
                    return previewController
                }
            }
        }
        return nil
    }
}
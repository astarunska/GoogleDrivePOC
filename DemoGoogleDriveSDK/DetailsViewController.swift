//
//  DetailsViewController.swift
//  DemoGoogleDriveSDK
//
//  Created by Aliona Starunska on 07.02.2022.
//

import UIKit
import GoogleAPIClientForREST

class DetailsViewController: UIViewController {
    
    var file: GTLRDrive_File?
    var data: Data?
    
    @IBOutlet private weak var titleLabel: UILabel!
    
    @IBOutlet private weak var textView: UITextView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        titleLabel.text = file?.name ?? "Failed to fetch file"
        guard let data = data else {
            return
        }
        let str = String(decoding: data, as: UTF8.self)
        textView.text = str
    }
    
    static func make(with file: GTLRDrive_File?, data: Data) -> DetailsViewController {
        let storyboard = UIStoryboard.init(name: "Main", bundle: .main)
        let vc = storyboard.instantiateViewController(withIdentifier: String(describing: DetailsViewController.self)) as? DetailsViewController ?? DetailsViewController()
        vc.file = file
        vc.data = data
        return vc
    }
}

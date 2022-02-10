//
//  ViewController.swift
//  DemoGoogleDriveSDK
//
//  Created by Aliona Starunska on 04.02.2022.
//

import UIKit
import GoogleSignIn
import GoogleAPIClientForREST

class ViewController: UIViewController {
    
    @IBOutlet private weak var loginButton: UIButton!
    @IBOutlet private weak var createFolderButton: UIButton!
    @IBOutlet private weak var saveButton: UIButton!
    @IBOutlet private weak var deleteButton: UIButton!
    @IBOutlet private weak var showListButton: UIButton!
    
    private var remoteTestFile: GTLRDrive_File?
    private let service: GDriveService = DefaultGDriveService(service: .init())
    
    override func viewDidLoad() {
        super.viewDidLoad()
        updateTitle()
    }
    
    // MARK: - actions
    
    @IBAction private func loginAction(_ sender: Any) {
        service.signIn(host: self) { [weak self] _, error in
            self?.show(error: error)
            self?.updateTitle()
        }
    }
    
    @IBAction private func createAction(_ sender: Any) {
        service.createFolderIfNeeded(folderName: "Calendars Attachments")  { [weak self] files, error in
            self?.show(error: error)
        }
    }
    
    @IBAction private func saveAction(_ sender: Any) {
        guard let file = fetchTestFile() else {
            showAlert(with: "Failed to fetch file")
            return
        }
        
        service.save(file: "TestFile",
                     data: file,
                     MIMEType: "application/vnd.google-apps.spreadsheet",
                     completion: { [weak self] error in
            self?.show(error: error)
        })
    }
    
    @IBAction private func deleteAction(_ sender: Any) {
        guard let remoteTestFile = remoteTestFile else {
            showAlert(with: "Nothing to delete")
            return
        }
        
        service.delete(file: remoteTestFile) { [weak self] error in
            self?.show(error: error)
        }
    }
    
    @IBAction private func listAction(_ sender: Any) {
        service.getFilesList { [weak self] files, error in
            self?.show(error: error)
            guard !files.isEmpty else {
                self?.showAlert(with: "No Files found")
                return
            }
            
            self?.showAlert(with: "Found files: \n" + files.compactMap({ $0.name }).joined(separator: "\n"))
            self?.remoteTestFile = files.first
        }
    }
    
    @IBAction private func downloadAction(_ sender: Any) {
        guard let remoteTestFile = remoteTestFile else {
            showAlert(with: "Nothing to delete")
            return
        }
        
        service.download(file: remoteTestFile) { [weak self] data, error in
            self?.show(error: error)
            if let data = data {
                let detailsVC = DetailsViewController.make(with: remoteTestFile, data: data)
                self?.present(detailsVC, animated: true, completion: nil)
            }
        }
    }
    
    // MARK: - private
    
    private func updateTitle() {
        let title = service.isSignedIn ? "Signed in! ✅" : "Login with Google"
        loginButton.setTitle(title, for: [])
    }
    
    private func fetchTestFile() -> Data? {
        guard let filePath = Bundle.main.url(forResource: "test_file123", withExtension: "rtf") else {
            return nil
        }
        return try? Data(contentsOf: filePath)
    }
    
    private func showAlert(with text: String) {
        let alert = UIAlertController(title: nil, message: text, preferredStyle: .alert)
        let action = UIAlertAction(title: "Ok", style: .default) { _ in
            alert.dismiss(animated: true, completion: nil)
        }
        alert.addAction(action)
        present(alert, animated: true, completion: nil)
    }
    
    private func show(error: GoogleError?) {
        guard let error = error else {
            return
        }
        showAlert(with: error.localizedDescription)
    }
}

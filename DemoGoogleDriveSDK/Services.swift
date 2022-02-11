//
//  Services.swift
//  DemoGoogleDriveSDK
//
//  Created by Aliona Starunska on 04.02.2022.
//

import UIKit
import GoogleSignIn
import GoogleAPIClientForREST

typealias SignInCompletion = (GIDGoogleUser?, GoogleError?) -> Void
typealias MetaDataCompletion = ([GTLRDrive_File], GoogleError?) -> Void
typealias FileDownloadCompletion = (Data?, GoogleError?) -> Void
typealias ErrorHandler = (GoogleError?) -> Void

protocol GDriveService {
    var isSignedIn: Bool { get }
    func signIn(host: UIViewController, completion: @escaping SignInCompletion)
    //    func createFolder(name: String, completion: @escaping ErrorHandler)
    func getFilesList(completion: @escaping MetaDataCompletion)
    func createFolderIfNeeded(folderName: String, completion: @escaping MetaDataCompletion)
    func save(file: String, data: Data, MIMEType: String, completion: @escaping ErrorHandler)
    func delete(file: GTLRDrive_File, completion: @escaping ErrorHandler)
    func download(file: GTLRDrive_File, completion: @escaping FileDownloadCompletion)
}

class DefaultGDriveService {
    
    private var service: GTLRDriveService
    private var folderID: String = .init()
    private let folderName = "Calendars Attachments"
    
    init(service: GTLRDriveService) {
        self.service = service
        GIDSignIn.sharedInstance.restorePreviousSignIn { _, _ in }
    }
}

extension DefaultGDriveService: GDriveService {
    
    var isSignedIn: Bool {
        return GIDSignIn.sharedInstance.currentUser != nil
    }
    
    func signIn(host: UIViewController, completion: @escaping SignInCompletion) {
        GIDSignIn.sharedInstance.signIn(with: .init(clientID: .clientID), presenting: host) { [weak self] user, error in
            guard let self = self else { return }
            
            if let error = error {
                print("SignIn failed, \(error), \(error.localizedDescription)")
            } else {
                print("Authenticate successfully")
                let driveScope = "https://www.googleapis.com/auth/drive"
                guard let user = user else { return }
                
                let grantedScopes = user.grantedScopes
                print("scopes: \(String(describing: grantedScopes))")
                self.createGoogleDriveService(user: user)
                
                if grantedScopes == nil || !grantedScopes!.contains(driveScope) {
                    GIDSignIn.sharedInstance.addScopes([driveScope], presenting: host) { [weak self] user, error in
                        
                        if let error = error {
                            print("add scope failed, \(error), \(error.localizedDescription)")
                        }
                        
                        guard let user = user else { return }
                        
                        if let scopes = user.grantedScopes,
                           scopes.contains(driveScope) {
                            self?.createGoogleDriveService(user: user)
                        }
                    }
                }
            }
        }
    }
    
    func createGoogleDriveService(user: GIDGoogleUser) {
        service.authorizer = user.authentication.fetcherAuthorizer()
        
        user.authentication.do { authentication, error in
            guard error == nil else { return }
            guard let authentication = authentication else { return }
            
            let service = GTLRDriveService()
            service.authorizer = authentication.fetcherAuthorizer()
        }
    }
    
    func getFilesList(completion: @escaping MetaDataCompletion) {
        guard isSignedIn else {
            completion([], GoogleError.unauthorized)
            return
        }
        
        let query = GTLRDriveQuery_FilesList.query()
        query.q = "'\(folderID)' in parents"
        query.pageSize = 100
        query.fields = "files(id, name, thumbnailLink)"
        
        service.executeQuery(query) { (ticket, result, error) in
            let fileList = result as? GTLRDrive_FileList
            let files = fileList?.files ?? []
            completion(files, error.map { GoogleError.failure($0.localizedDescription) })
        }
    }
    
    func save(file: String, data: Data, MIMEType: String, completion: @escaping ErrorHandler) {
        guard isSignedIn else {
            completion(GoogleError.unauthorized)
            return
        }
        
        let googleFile = GTLRDrive_File()
        googleFile.name = file
        googleFile.parents = [folderID]
        
        let params = GTLRUploadParameters(data: data, mimeType: "application/rtf")
        params.shouldUploadWithSingleRequest = true
        
        let query = GTLRDriveQuery_FilesCreate.query(withObject: googleFile, uploadParameters: params)
        query.fields = "id"
        
        service.executeQuery(query) { (ticket, file, error) in
            completion(error.map { GoogleError.failure($0.localizedDescription) })
        }
    }
    
    func delete(file: GTLRDrive_File, completion: @escaping ErrorHandler) {
        guard isSignedIn else {
            completion(GoogleError.unauthorized)
            return
        }
        
        guard let fileID = file.identifier else {
            return completion(nil)
        }
        
        service.executeQuery(GTLRDriveQuery_FilesDelete.query(withFileId: fileID)) { (ticket, nilFile, error) in
            completion(error.map { GoogleError.failure($0.localizedDescription) })
        }
    }
    
    func download(file: GTLRDrive_File, completion: @escaping FileDownloadCompletion) {
        guard isSignedIn else {
            completion(nil, GoogleError.unauthorized)
            return
        }
        
        guard let fileID = file.identifier else {
            return completion(nil, GoogleError.failure("Missing file ID"))
        }
        
        service.executeQuery(GTLRDriveQuery_FilesGet.queryForMedia(withFileId: fileID)) { (ticket, file, error)  in
            guard let data = (file as? GTLRDataObject)?.data else {
                return completion(nil, error.map { GoogleError.failure($0.localizedDescription) })
            }
            
            completion(data, error.map { GoogleError.failure($0.localizedDescription) })
        }
    }
    
    func createFolderIfNeeded(folderName: String, completion: @escaping MetaDataCompletion) {
        guard isSignedIn else {
            completion([], GoogleError.unauthorized)
            return
        }
        
        let query = GTLRDriveQuery_FilesList.query()
        query.pageSize = 100
        
        service.executeQuery(query) { (ticket, result, error) in
            let fileList = result as? GTLRDrive_FileList
            let files = fileList?.files ?? []
            
            if files.first(where: { $0.name == folderName}) == nil  {
                self.createFolder(name: folderName) { error in
                    completion([], error.map { GoogleError.failure($0.localizedDescription) })
                }
            } else {
                self.folderID = files.first(where: { $0.name == folderName})?.identifier ?? ""
            }
        }
    }
    
    private func createFolder(name: String, completion: @escaping ErrorHandler) {
        guard isSignedIn else {
            completion(GoogleError.unauthorized)
            return
        }
        
        let parentId = "root"
        let metadata = GTLRDrive_File()
        metadata.name = folderName
        metadata.mimeType = "application/vnd.google-apps.folder"
        metadata.parents = [parentId]
        
        let query = GTLRDriveQuery_FilesCreate.query(withObject: metadata, uploadParameters: nil)
        query.fields = "id"
        
        service.executeQuery(query) { (ticket, object, error) in
            self.folderID = (object as? GTLRDrive_File)?.identifier ?? ""
            completion(error.map { GoogleError.failure($0.localizedDescription) })
        }
    }
    
}

// MARK: - Constants

fileprivate extension String {
#warning("Add CLIENT ID")
    // TODO: Replace CLIENT ID with correct one
    static var clientID: String { "240237140694-43tdjn92novddbhuggn91sd717op04np.apps.googleusercontent.com" }
}

// MARK: - Errors

enum GoogleError: Error {
    case unauthorized
    case failure(String)
}

extension GoogleError {
    var localizedDescription: String {
        switch self {
        case .unauthorized:
            return "Please Sign In before using Google Drive"
        case .failure(let string):
            return string
        }
    }
}

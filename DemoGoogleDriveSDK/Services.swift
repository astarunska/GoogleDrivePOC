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
    func createFolder(name: String, completion: @escaping ErrorHandler)
    func getFilesList(completion: @escaping MetaDataCompletion)
    func save(file: String, data: Data, MIMEType: String, completion: @escaping ErrorHandler)
    func delete(file: GTLRDrive_File, completion: @escaping ErrorHandler)
    func download(file: GTLRDrive_File, completion: @escaping FileDownloadCompletion)
}

class DefaultGDriveService {
    
    private let service: GTLRDriveService
    private let folderName = "Calendars Test"
    
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
        GIDSignIn.sharedInstance.signIn(with: .init(clientID: .clientID), presenting: host) { user, error in
            completion(user, error.map { GoogleError.failure($0.localizedDescription) })
        }
    }
    
    func createFolder(name: String, completion: @escaping ErrorHandler) {
        guard isSignedIn else {
            completion(GoogleError.unauthorized)
            return
        }
        
        let metadata = GTLRDrive_File()
        metadata.name = "Readdle Calendar"
        
        metadata.mimeType = "application/vnd.google-apps.folder"
        let query = GTLRDriveQuery_FilesCreate.query(withObject: metadata, uploadParameters: nil)
        query.fields = "id"
        
        service.executeQuery(query) { (ticket: GTLRServiceTicket, object: Any?, error: Error?) in
            completion(error.map { GoogleError.failure($0.localizedDescription) })
        }
    }
    
    func getFilesList(completion: @escaping MetaDataCompletion) {
        guard isSignedIn else {
            completion([], GoogleError.unauthorized)
            return
        }
        
        let query = GTLRDriveQuery_FilesList.query()
        query.pageSize = 100
        query.q = "'\(folderName)' in parents and mimeType != 'application/vnd.google-apps.folder'"
        
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
        
        let file = GTLRDrive_File()
        file.name = file.name
        file.parents = [folderName]
        
        let params = GTLRUploadParameters(data: data, mimeType: MIMEType)
        params.shouldUploadWithSingleRequest = true
        
        let query = GTLRDriveQuery_FilesCreate.query(withObject: file, uploadParameters: params)
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

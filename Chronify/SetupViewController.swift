//
//  SetupViewController.swift
//  SetupViewController
//
//  Created by Joseph Simeone on 8/31/21.
//

import UIKit
import SpotifyWebAPI
import Combine
import KeychainAccess

class SetupViewController: UIViewController {
    
    //MARK: Variables
    
    
   
    
    var cancellables: Set<AnyCancellable> = []
    
    static let authorizationManagerKey = "authorizationManager"
    @Published var isAuthorized = false
    private let keychain = Keychain(service: "com.simeone.Chronify")
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        //Notification observers for after authorization requests come back.
        NotificationCenter.default.addObserver(self, selector: #selector(handleSpotifyAuthorization(_:)), name: Notification.Name("spotify"), object: nil)
        
        // Do any additional setup after loading the view.
        //MARK: Call authorize()
    }
    
   
    
    //Handle responses from the API people. Error handling is important!
    @objc func handleSpotifyAuthorization(_ notification: NSNotification) {
        
        if let url = notification.userInfo?["url"] as? URL {
            spotify.authorizationManager.requestAccessAndRefreshTokens(
                redirectURIWithQuery: url,
                // Must match the code verifier that was used to generate the
                // code challenge when creating the authorization URL.
                codeVerifier: codeVerifier,
                // Must match the value used when creating the authorization URL.
                state: state
            )
            .sink(receiveCompletion: { completion in
                switch completion {
                    case .finished:
                        print("successfully authorized")
                    case .failure(let error):
                        if let authError = error as? SpotifyAuthorizationError, authError.accessWasDenied {
                            print("The user denied the authorization request")
                        }
                        else {
                            print("couldn't authorize application: \(error)")
                        }
                }
            })
            .store(in: &cancellables)
        }
        
    }
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}

final class Spotify: ObservableObject {
    
    let spotify = SpotifyAPI(authorizationManager: AuthorizationCodeFlowPKCEManager(clientId: "ea1608401fca4e809a843f5d4740ee3c"))
    let state = String.randomURLSafe(length: 128)
    
    let codeVerifier = String.randomURLSafe(length: 128)
    var codeChallenge: String = ""
    
    static let authorizationManagerKey = "authorizationManager"
    static let loginCallbackURL = URL(string: "https://chronifyapp.wordpress.com/callback")!
    var authorizationState = String.randomURLSafe(length: 128)
    
    @Published var isAuthorized = false
    
    private let keychain = Keychain(service: "com.simeone.Chronify")
    
    let api = SpotifyAPI(authorizationManager: AuthorizationCodeFlowPKCEManager(clientId: "ea1608401fca4e809a843f5d4740ee3c"))
    
    var cancellables: [AnyCancellable] = []
    
    init() {
        self.api.authorizationManagerDidChange
            .receive(on: RunLoop.main)
            .sink(receiveValue: authorizationManagerDidChange)
            .store(in: &cancellables)
        
        self.api.authorizationManagerDidDeauthorize
            .receive(on: RunLoop.main)
            .sink(receiveValue: authorizationManagerDidDeauthorize)
            .store(in: &cancellables)
        
        //Check to see if the information to authorize is saved in the keychain
        if let authManagerData = keychain[data: Self.authorizationManagerKey] {
            do {
                let authorizationManager = try JSONDecoder().decode(AuthorizationCodeFlowPKCEManager.self, from: authManagerData)
                self.api.authorizationManager = authorizationManager
            } catch {
                print("could not properly decode authorization manager from data: \(error)")
            }
        } else {
            print("no auth info in keychain")
        }
    }
    
    private func authorize() {
        codeChallenge = String.makeCodeChallenge(codeVerifier: codeVerifier)
        let authorizationURL = spotify.authorizationManager.makeAuthorizationURL(
            redirectURI: Self.loginCallbackURL,
            codeChallenge: codeChallenge,
            state: self.authorizationState,
            scopes: [
                .userReadRecentlyPlayed,
                .userReadCurrentlyPlaying
            ]
        )!
        
        UIApplication.shared.open(authorizationURL)
    }
    
    func authorizationManagerDidChange() {
        self.isAuthorized = self.api.authorizationManager.isAuthorized()
        
        do {
            let authManagerData = try JSONEncoder().encode(self.api.authorizationManager)
            self.keychain[data: Self.authorizationManagerKey] = authManagerData
        } catch {
            print("Couldn't encode authorizationManager for storage in the keychain: \(error)")
        }
    }
    
    func authorizationManagerDidDeauthorize() {
        self.isAuthorized = false
        
        do {
            try self.keychain.remove(Self.authorizationManagerKey)
            print("removed auth manager from keychain")
        } catch {
            print("could not remove auth manager from keychain: \(error)")
        }
    }
}

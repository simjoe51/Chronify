//
//  SetupViewController.swift
//  SetupViewController
//
//  Created by Joseph Simeone on 8/31/21.
//

import UIKit
import SpotifyWebAPI
import Combine

class SetupViewController: UIViewController {
    
    //MARK: Variables
    let spotify = SpotifyAPI(authorizationManager: AuthorizationCodeFlowPKCEManager(clientId: "ea1608401fca4e809a843f5d4740ee3c"))
    
    let codeVerifier = String.randomURLSafe(length: 128)
    var codeChallenge: String = ""
    let state = String.randomURLSafe(length: 128)
    var cancellables: Set<AnyCancellable> = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        //Make variables what they're supposed to be
        codeChallenge = String.makeCodeChallenge(codeVerifier: codeVerifier)
        
        //Notification observers for after authorization requests come back.
        NotificationCenter.default.addObserver(self, selector: #selector(handleSpotifyAuthorization(_:)), name: Notification.Name("spotify"), object: nil)
        
        // Do any additional setup after loading the view.
        registerSpotify()
    }
    
    private func registerSpotify() {
        let authorizationURL = spotify.authorizationManager.makeAuthorizationURL(
            redirectURI: URL(string: "https://chronifyapp.wordpress.com/callback")!,
            codeChallenge: codeChallenge,
            state: state,
            scopes: [
                .userReadRecentlyPlayed
            ]
        )!
        
        UIApplication.shared.open(authorizationURL)
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

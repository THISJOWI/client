import Flutter
import UIKit
import AuthenticationServices

@main
@objc class AppDelegate: FlutterAppDelegate {
    
    private let credentialChannelName = "com.thisjowi/credentials"
    private let autofillChannelName = "com.thisjowi/autofill"
    private let appGroupIdentifier = "group.com.thisjowi.passwords"
    
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        GeneratedPluginRegistrant.register(with: self)
        
        setupMethodChannels()
        
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
    
    private func setupMethodChannels() {
        guard let controller = window?.rootViewController as? FlutterViewController else {
            return
        }
        
        // Credential sharing channel
        let credentialChannel = FlutterMethodChannel(
            name: credentialChannelName,
            binaryMessenger: controller.binaryMessenger
        )
        
        credentialChannel.setMethodCallHandler { [weak self] (call, result) in
            self?.handleCredentialMethodCall(call: call, result: result)
        }
        
        // Autofill settings channel
        let autofillChannel = FlutterMethodChannel(
            name: autofillChannelName,
            binaryMessenger: controller.binaryMessenger
        )
        
        autofillChannel.setMethodCallHandler { [weak self] (call, result) in
            self?.handleAutofillMethodCall(call: call, result: result)
        }
    }
    
    private func handleCredentialMethodCall(call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "syncPasswordsToAppGroup":
            guard let args = call.arguments as? [String: Any],
                  let passwordsJson = args["passwords"] as? String else {
                result(false)
                return
            }
            
            let success = syncPasswordsToAppGroup(passwordsJson: passwordsJson)
            result(success)
            
        case "registerCredentialIdentities":
            guard let args = call.arguments as? [String: Any],
                  let credentialsJson = args["credentials"] as? String else {
                result(false)
                return
            }
            
            registerCredentialIdentities(credentialsJson: credentialsJson) { success in
                result(success)
            }
            
        case "clearCredentialIdentities":
            clearCredentialIdentities { success in
                result(success)
            }
            
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    private func handleAutofillMethodCall(call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "hasAutofillSupport":
            result(true) // iOS 12+ always supports AutoFill
            
        case "isAutofillServiceEnabled":
            // We can't programmatically check if our extension is enabled
            result(true)
            
        case "openAutofillSettings":
            // Can't directly open password settings on iOS
            result(false)
            
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    // MARK: - Credential Sharing
    
    private func syncPasswordsToAppGroup(passwordsJson: String) -> Bool {
        guard let data = passwordsJson.data(using: .utf8),
              let sharedDefaults = UserDefaults(suiteName: appGroupIdentifier) else {
            return false
        }
        
        sharedDefaults.set(data, forKey: "passwords")
        sharedDefaults.synchronize()
        return true
    }
    
    private func registerCredentialIdentities(credentialsJson: String, completion: @escaping (Bool) -> Void) {
        guard let data = credentialsJson.data(using: .utf8),
              let credentials = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            completion(false)
            return
        }
        
        let store = ASCredentialIdentityStore.shared
        
        // Check if store is enabled
        store.getState { state in
            guard state.isEnabled else {
                completion(false)
                return
            }
            
            // Create credential identities
            var identities: [ASPasswordCredentialIdentity] = []
            
            for credential in credentials {
                guard let id = credential["id"] as? String,
                      let username = credential["username"] as? String,
                      let website = credential["website"] as? String,
                      !website.isEmpty else {
                    continue
                }
                
                let serviceIdentifier = ASCredentialServiceIdentifier(
                    identifier: website,
                    type: .domain
                )
                
                let identity = ASPasswordCredentialIdentity(
                    serviceIdentifier: serviceIdentifier,
                    user: username,
                    recordIdentifier: id
                )
                
                identities.append(identity)
            }
            
            // Replace all identities
            store.replaceCredentialIdentities(with: identities) { success, error in
                if let error = error {
                    print("Error registering credentials: \(error)")
                }
                completion(success)
            }
        }
    }
    
    private func clearCredentialIdentities(completion: @escaping (Bool) -> Void) {
        let store = ASCredentialIdentityStore.shared
        
        store.removeAllCredentialIdentities { success, error in
            if let error = error {
                print("Error clearing credentials: \(error)")
            }
            completion(success)
        }
    }
}


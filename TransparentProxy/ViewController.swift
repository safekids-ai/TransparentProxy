//
//  ViewController.swift
//  TransparentProxy
//
//  Created by Mac User on 06/05/2021.
//

import Cocoa
import NetworkExtension
import SystemExtensions
import os.log

class ViewController: NSViewController {

    enum Status {
        case stopped
        case indeterminate
        case running
    }
    
    var status: Status = .stopped
    
//    let manager = NETransparentProxyManager.shared()
    
    // Get the Bundle of the system extension.
    lazy var extensionBundle: Bundle = {

        let extensionsDirectoryURL = URL(fileURLWithPath: "Contents/Library/SystemExtensions", relativeTo: Bundle.main.bundleURL)
        let extensionURLs: [URL]
        do {
            extensionURLs = try FileManager.default.contentsOfDirectory(at: extensionsDirectoryURL,
                                                                        includingPropertiesForKeys: nil,
                                                                        options: .skipsHiddenFiles)
        } catch let error {
            fatalError("Failed to get the contents of \(extensionsDirectoryURL.absoluteString): \(error.localizedDescription)")
        }

        guard let extensionURL = extensionURLs.first else {
            fatalError("Failed to find any system extensions")
        }

        guard let extensionBundle = Bundle(url: extensionURL) else {
            fatalError("Failed to create a bundle with URL \(extensionURL.absoluteString)")
        }

        return extensionBundle
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
//        clearPreferences()
//        startTunnel()
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }
    

    @IBAction func startProxy(_ sender: Any) {
        startTunnel()
    }
    
    @IBAction func stopProxy(_ sender: Any) {
        stopTunnel()
    }
    
    @IBAction func clear(_ sender: Any) {
        clearPreferences()
    }
    
    @IBAction func enable(_ sender: Any) {
        enableConfiguration()
    }
    
    @IBAction func disable(_ sender: Any) {
        let manager = NETransparentProxyManager()
        loadAndUpdatePreferences(using: manager) {
            manager in
            manager.isEnabled = false
        }
    }
    
    @IBAction func initialize(_ sender: Any) {
        guard let extensionIdentifier = extensionBundle.bundleIdentifier else {
            self.status = .stopped
            return
        }

        // Start by activating the system extension
        let activationRequest = OSSystemExtensionRequest.activationRequest(forExtensionWithIdentifier: extensionIdentifier, queue: .main)
        activationRequest.delegate = self
        OSSystemExtensionManager.shared.submitRequest(activationRequest)
    }
    
    private func loadAndUpdatePreferences(using manager: NETransparentProxyManager, _ completionHandler: @escaping (NETransparentProxyManager) -> Void) {
        manager.loadFromPreferences { error in
            guard error == nil else {
                os_log("load error: %@", error!.localizedDescription)
                return
            }

//            os_log("calling completionHandler")
            completionHandler(manager)
//            os_log("completionHandler returned")

            manager.saveToPreferences { (error) in
                guard error == nil else {
                    os_log("save error: %@", error!.localizedDescription)
                    return
                }

                os_log("saved")
            }
        }
    }
    
    private func clearPreferences(){
        NETransparentProxyManager.loadAllFromPreferences{ (managers, error) in

            guard error == nil else {
                os_log("load error: %@", error!.localizedDescription)
                return
            }
            for manager in managers ?? [] {
                manager.removeFromPreferences(completionHandler: nil)
            }
        }
    }
    private func startTunnel() {
        NETransparentProxyManager.loadAllFromPreferences{ (managers, error) in

            guard error == nil else {
                os_log("load error: %@", error!.localizedDescription)
                return
            }
            
            for manager in managers ?? [] {
                os_log("startTunnel: manager %@", manager)
                do{
                    try manager.connection.startVPNTunnel(options: [:])
                }
                catch{
                    
                }
            }
        }
    }
    private func stopTunnel() {
        NETransparentProxyManager.loadAllFromPreferences{ (managers, error) in

            guard error == nil else {
                os_log("load error: %@", error!.localizedDescription)
                return
            }
            
            for manager in managers ?? [] {
                os_log("startTunnel: manager %@", manager)
                manager.connection.stopVPNTunnel()
            }
        }
    }
    func enableConfiguration() {
        let manager = NETransparentProxyManager()
        loadAndUpdatePreferences(using: manager){
            manager in
            
            let config = NETunnelProviderProtocol()
            config.providerBundleIdentifier = self.extensionBundle.bundleIdentifier
            config.providerConfiguration = [:]
            config.serverAddress = "127.0.0.1"

            manager.localizedDescription = "proxy"
            manager.protocolConfiguration = config

            manager.isEnabled = true
        }
    }
}


extension ViewController: OSSystemExtensionRequestDelegate {

    // MARK: OSSystemExtensionActivationRequestDelegate

    func request(_ request: OSSystemExtensionRequest, didFinishWithResult result: OSSystemExtensionRequest.Result) {

        os_log("Request completed with result: %d", result.rawValue)
        
        guard result == .completed else {
            os_log("Unexpected result %d for system extension request", result.rawValue)
            status = .stopped
            return
        }

//        enableConfiguration()
    }

    func request(_ request: OSSystemExtensionRequest, didFailWithError error: Error) {

        os_log("System extension request failed: %@", error.localizedDescription)
        status = .stopped
    }

    func requestNeedsUserApproval(_ request: OSSystemExtensionRequest) {

        os_log("Extension %@ requires user approval", request.identifier)
    }

    func request(_ request: OSSystemExtensionRequest,
                 actionForReplacingExtension existing: OSSystemExtensionProperties,
                 withExtension extension: OSSystemExtensionProperties) -> OSSystemExtensionRequest.ReplacementAction {

        os_log("Replacing extension %@ version %@ with version %@", request.identifier, existing.bundleShortVersion, `extension`.bundleShortVersion)
        return .replace
    }
}

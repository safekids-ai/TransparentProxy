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
    
    let manager = NETransparentProxyManager.shared()
    
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
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }
    

    @IBAction func startProxy(_ sender: Any) {
        guard let extensionIdentifier = extensionBundle.bundleIdentifier else {
            self.status = .stopped
            return
        }

        // Start by activating the system extension
        let activationRequest = OSSystemExtensionRequest.activationRequest(forExtensionWithIdentifier: extensionIdentifier, queue: .main)
        activationRequest.delegate = self
        OSSystemExtensionManager.shared.submitRequest(activationRequest)
    }
    
    @IBAction func stopProxy(_ sender: Any) {
        
        loadAndUpdatePreferences {
            [weak self] in
            self?.manager.isEnabled = false
        }
    }
    
    private func loadAndUpdatePreferences(_ completion: @escaping () -> Void) {
        manager.loadFromPreferences { [weak self] error in
            guard error == nil else {
                os_log("load error: %@", error!.localizedDescription)
                return
            }

            completion()

            self?.manager.saveToPreferences { (error) in
                guard error == nil else {
                    os_log("save error: %@", error!.localizedDescription)
                    return
                }

                os_log("saved")
            }
        }
    }
    
    private func startTunnel() {
        NETransparentProxyManager.loadAllFromPreferences() { (managers, error) in

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
    
    func enableConfiguration() {
        loadAndUpdatePreferences {
            [weak self] in
            
            let config = NETunnelProviderProtocol()
            config.providerBundleIdentifier = self?.extensionBundle.bundleIdentifier
            config.providerConfiguration = [:]
            config.serverAddress = "127.0.0.1"

            self?.manager.localizedDescription = "transparent proxy"
            self?.manager.protocolConfiguration = config

            self?.manager.isEnabled = true
        }
        startTunnel()
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

        enableConfiguration()
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

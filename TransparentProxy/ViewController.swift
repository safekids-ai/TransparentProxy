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
        let manager = NETransparentProxyManager.shared()
        
        status = .indeterminate
        
        guard !manager.isEnabled else {
            status = .running
            return
        }

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
        let manager = NETransparentProxyManager.shared()

        status = .indeterminate

        guard manager.isEnabled else {
            status = .stopped
            return
        }

        loadConfiguration { success in
            guard success else {
                self.status = .running
                return
            }

            manager.isEnabled = false
            manager.saveToPreferences { saveError in
                DispatchQueue.main.async {
                    if let error = saveError {
                        os_log("Failed to disable configuration: %@", error.localizedDescription)
                        self.status = .running
                        return
                    }

                    self.status = .stopped
                }
            }
        }
    }
    
    func loadConfiguration(completionHandler: @escaping (Bool) -> Void) {

        NETransparentProxyManager.shared().loadFromPreferences { loadError in
            DispatchQueue.main.async {
                var success = true
                if let error = loadError {
                    os_log("Failed to load configuration: %@", error.localizedDescription)
                    success = false
                }
                completionHandler(success)
            }
        }
    }

    
    func enableConfiguration() {

        let manager = NETransparentProxyManager.shared()

        guard !manager.isEnabled else {
            os_log("Already enabled")
            status = .running
            return
        }

        loadConfiguration { success in

            guard success else {
                self.status = .stopped
                return
            }

            let config = NETunnelProviderProtocol()
            config.providerBundleIdentifier = self.extensionBundle.bundleIdentifier
            config.providerConfiguration = ["listen-ports": ["80", "443"]]

            manager.protocolConfiguration = config
            
//            manager.protocolConfiguration = nil
            
            manager.isEnabled = true

            manager.saveToPreferences { saveError in
                DispatchQueue.main.async {
                    if let error = saveError {
                        os_log("Failed to enable configuration: %@", error.localizedDescription)
                        self.status = .stopped
                        return
                    }

                    self.status = .running
                }
            }
        }
    }
}


extension ViewController: OSSystemExtensionRequestDelegate {

    // MARK: OSSystemExtensionActivationRequestDelegate

    func request(_ request: OSSystemExtensionRequest, didFinishWithResult result: OSSystemExtensionRequest.Result) {

        os_log("Requst completed with resutl: %d", result.rawValue)
        
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

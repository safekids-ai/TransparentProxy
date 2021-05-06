//
//  AppProxyProvider.swift
//  TransparentProxyProvider
//
//  Created by Mac User on 06/05/2021.
//

import NetworkExtension
import os.log

@available(OSX 11.0, *)
class AppProxyProvider: NETransparentProxyProvider {

    override func startProxy(options: [String : Any]?, completionHandler: @escaping (Error?) -> Void) {
        // Add code here to start the process of connecting the tunnel.
        
        let networkRules = ["443","80"].map { port -> NENetworkRule in
            let remoteNetwork = NWHostEndpoint(hostname: "0.0.0.0", port: port)
            
            return NENetworkRule(remoteNetwork: remoteNetwork,
                                                   remotePrefix: 0,
                                                   localNetwork: nil,
                                                   localPrefix: 0,
                                                   protocol: .TCP,
                                                   direction: .outbound)
        }

        let proxySettings = NETransparentProxyNetworkSettings()
        proxySettings.includedNetworkRules = networkRules
        
        setTunnelNetworkSettings(proxySettings) { error in
            if let applyError = error {
                os_log("Failed to apply tunnel settings settings: %{public}@", applyError.localizedDescription)
            }
            completionHandler(error)
        }
    }
    
    override func stopProxy(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        // Add code here to start the process of stopping the tunnel.
        completionHandler()
    }
    
    override func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)?) {
        // Add code here to handle the message.
        if let handler = completionHandler {
            handler(messageData)
        }
    }
    
    override func sleep(completionHandler: @escaping () -> Void) {
        // Add code here to get ready to sleep.
        completionHandler()
    }
    
    override func wake() {
        // Add code here to wake up.
    }
    
    override func handleNewFlow(_ flow: NEAppProxyFlow) -> Bool {
        // Add code here to handle the incoming flow.
        return false
    }
}

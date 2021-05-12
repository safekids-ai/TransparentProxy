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
        
        /*
         {
             AuthMethod = Password;
             ServerAddress = "http://127.0.0.1:8080";
             VendorData =     {
                 ports =         (
                     80,
                     443
                 );
             };
         }
         */
        
        os_log("startProxy options: %{public}@", options as! CVarArg)
        
        let vendorData = options?["VendorData"] as? Dictionary<String, Any>
        let ports = vendorData?["ports"] as! [String]
        let tunnelRemoteAddress = vendorData?["tunnelRemoteAddress"] as! String
        
        let networkRules = ports.map { port -> NENetworkRule in
            let remoteNetwork = NWHostEndpoint(hostname: "0.0.0.0", port: port)
            
            return NENetworkRule(remoteNetwork: remoteNetwork,
                                                   remotePrefix: 0,
                                                   localNetwork: nil,
                                                   localPrefix: 0,
                                                   protocol: .TCP,
                                                   direction: .outbound)
        }

        let proxySettings = NETransparentProxyNetworkSettings(tunnelRemoteAddress: tunnelRemoteAddress)
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
        os_log("stopProxy")
        completionHandler()
    }
    
    override func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)?) {
        // Add code here to handle the message.
        
        guard let messageString = String(data: messageData, encoding: String.Encoding.utf8) else {
                    completionHandler?(nil)
                    return
                }
        
        os_log("message data: %{public}@", messageString)
        
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
        if let tcpflow = flow as? NEAppProxyTCPFlow
        {
            os_log("tcpflow handled - %{public}@",tcpflow.metaData.debugDescription)
            os_log("tcpflow remoteEndpoint - %{public}@",tcpflow.remoteEndpoint)
        }
        else if let udpflow = flow as? NEAppProxyUDPFlow
        {
            os_log("udpflow handled - %{public}@", udpflow.metaData.debugDescription)
        }
        else
        {
            os_log("flow handled - %{public}@",flow.metaData.debugDescription)
        }
        return true
    }
}

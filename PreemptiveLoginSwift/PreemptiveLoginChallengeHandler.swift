/**
 * Copyright 2016 IBM Corp.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import UIKit
import IBMMobileFirstPlatformFoundation

class PreemptiveLoginChallengeHandler: SecurityCheckChallengeHandler {
    var isChallenged: Bool
    let defaults = UserDefaults.standard
    let securityCheckName = "UserLogin"
    
    override init(){
        self.isChallenged = false
        super.init(securityCheck: "UserLogin")
        WLClient.sharedInstance().register(self)
        
        // Add notifications observers
        NotificationCenter.default.addObserver(self, selector: #selector(login(_:)), name: NSNotification.Name(rawValue: LoginNotificationKey), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(logout), name: NSNotification.Name(rawValue: LogoutNotificationKey), object: nil)
    }
    
    // login (Triggered by Login Notification)
    func login(_ notification:Notification){
        let userInfo = notification.userInfo as! Dictionary<String, AnyObject?>
        let username = userInfo["username"] as! String
        let password = userInfo["password"] as! String
        
        // If challenged use submitChallengeAnswer API, else use login API
        if(!self.isChallenged){
            WLAuthorizationManager.sharedInstance().login(self.securityCheckName, withCredentials: ["username": username, "password": password]) { (error) -> Void in
                if(error != nil){
                    print("Login failed \(error!.localizedDescription)")
                }
            }
        }
        else{
            self.submitChallengeAnswer(["username": username, "password": password])
        }
    }
    
    // logout (Triggered by Logout Notification)
    func logout(){
        WLAuthorizationManager.sharedInstance().logout(self.securityCheckName){
            (error) -> Void in
            if(error != nil){
                print("Logout failed \(error!.localizedDescription)")
            }
            self.isChallenged = false
        }
        
    }
    
    // handleChallenge
    override func handleChallenge(_ challenge: [AnyHashable: Any]!) {
        self.isChallenged = true
        var errMsg: String!
        self.defaults.removeObject(forKey: "displayName")
        if(challenge["errorMsg"] is NSNull){
            errMsg = ""
        }
        else{
            errMsg = challenge["errorMsg"] as! String
        }
        let remainingAttempts = challenge["remainingAttempts"]
        
        NotificationCenter.default.post(name: Notification.Name(rawValue: LoginRequiredNotificationKey), object: nil, userInfo: ["errorMsg":errMsg!, "remainingAttempts":remainingAttempts!])
        
    }
    
    // handleSuccess
    override func handleSuccess(_ success: [AnyHashable: Any]!) {
        self.isChallenged = false
        if let user = success["user"] as? Dictionary<String, Any> {
            if let displayName = user["displayName"] as? String {
                self.defaults.set(displayName, forKey: "displayName")
                NotificationCenter.default.post(name: Notification.Name(rawValue: LoginSuccessNotificationKey), object: nil)
            }
        }
    }
    
    // handleFailure
    override func handleFailure(_ failure: [AnyHashable: Any]!) {
        self.isChallenged = false
        if let _ = failure["failure"] as? String {
            NotificationCenter.default.post(name: Notification.Name(rawValue: LoginFailureNotificationKey), object: nil, userInfo: ["errorMsg":failure["failure"]!])
        }
        else{
            NotificationCenter.default.post(name: Notification.Name(rawValue: LoginFailureNotificationKey), object: nil, userInfo: ["errorMsg":"Unknown error"])
        }
    }
}

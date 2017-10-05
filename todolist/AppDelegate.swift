//
//  AppDelegate.swift
//  todolist
//
//  Created by Samantha Emily-Rachel Belnavis on 2017-10-02.
//  Copyright © 2017 Samantha Emily-Rachel Belnavis. All rights reserved.
//

import UIKit
import CoreData
import Firebase
import GoogleSignIn
import SwiftyPlistManager

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, GIDSignInDelegate {

  var window: UIWindow?
  
  // app specific variables
  var connectionAvailable: Bool!
  var plistPathInDocument: String = String()
  let userDefaults = UserDefaults.standard
  let plistManager = SwiftyPlistManager.shared
  
  // plist list
  var preferencesPlist = "UserPrefs"
  var themesPlist = "ThemesList"
  
  // individual theme property lists
  var theme0 = "defaultTheme"
  var theme1 = "lightTheme"
  var theme2 = "darkTheme"
  var theme3 = "tangerineTheme"
  var theme4 = "sunflowerTheme"
  var theme5 = "cloverTheme"
  var theme6 = "blueberryTheme"
  var theme7 = "skyBlueTheme"
  var theme8 = "amethystTheme"
  var theme9 = "graphiteTheme"
  
  // google signin user variables
  var googleUsersId = String()
  var googleUsersName = String()
  var googleUsersEmail = String()
  var googleUsersGender = String()
  var googleUsersPhoto: URL!
  var googleUsersPhotoAsString = String()

  // create firebase database reference
  var databaseRef: DatabaseReference!
  
  // internet connectivity
  var internetConnected: Bool!
 

  func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
    // initialize firebase application
    FirebaseApp.configure()
    
    // google login instance setup
    GIDSignIn.sharedInstance().clientID = FirebaseApp.app()?.options.clientID
    GIDSignIn.sharedInstance().delegate = self
    
    plistManager.start(plistNames: [preferencesPlist, themesPlist, theme0, theme1, theme2, theme3, theme4, theme5, theme6, theme7, theme8, theme9], logging: true)
    
    return true
  }
  
  func checkInternet() {
    guard let status = Network.reachability?.status else { return }
    switch status {
    case .unreachable:
      print ("Internet unreachable")
      return connectionAvailable = false
    case .wifi:
      print ("Internet reachable")
      return connectionAvailable = true
    case .wwan:
      print ("Internet reachable")
      return connectionAvailable = true
    }
  }
  
  
  func sign(_ signIn: GIDSignIn, didSignInFor user: GIDGoogleUser!, withError error: Error?) {
    if error != nil {
      return
    }
    
    guard let authentication = user.authentication else { return }
    let credential = GoogleAuthProvider.credential(withIDToken: authentication.idToken, accessToken: authentication.accessToken)
    
    // retrieve details from the google user's profile
    googleUsersId = user.userID
    googleUsersName = user.profile.name
    googleUsersEmail = user.profile.email
    googleUsersPhoto = user.profile.imageURL(withDimension: 100 * UInt(UIScreen.main.scale))!
    googleUsersPhotoAsString = googleUsersPhoto.absoluteString
    
    print("appdelegate value: " + googleUsersId)
    print("appdelegate value: " + googleUsersEmail)
    print("appdelegate value: " + googleUsersName)
    
    plistManager.save(googleUsersPhotoAsString, forKey: "userPhotoUrl", toPlistWithName: preferencesPlist) { (err) in
      if err == nil { return }
    }
    
    self.databaseRef = Database.database().reference()
    self.databaseRef.child("user_profiles").child(self.googleUsersId).observeSingleEvent(of: .value, with: { (snapshot) in
      let snapshot = snapshot.value as? NSDictionary
      
      if (snapshot == nil) {
        self.databaseRef.child("user_profiles").child(self.googleUsersId).child("id").setValue(self.googleUsersId)
        self.databaseRef.child("user_profiles").child(self.googleUsersId).child("name").setValue(self.googleUsersName)
        self.databaseRef.child("user_profiles").child(self.googleUsersId).child("email").setValue(self.googleUsersEmail)
        self.databaseRef.child("user_profiles").child(self.googleUsersId).child("image_url").setValue(self.googleUsersPhotoAsString)
      }
    })
    Auth.auth().signIn(with: credential) { (user, error) in
      if error != nil {
        return
      }
    }
    return
  }
  
  // get image from source asynchronously
  func getImageFromUrl(url: URL, completion: @escaping (_ data: Data?, _ response: URLResponse?, _ error: Error?) -> Void) {
    URLSession.shared.dataTask(with: url) {
      (data, response, error) in
      completion(data, response, error)
    }.resume()
  }
  
  func downloadUserImage(url: URL) {
    print("Download started")
    getImageFromUrl(url: url) { (data, response, error) in
      guard let data = data, error == nil else { return }
      print ("Download finished")
      DispatchQueue.main.async { () -> Void in
        let userImageData = data
        // save to file
        let documentsDirectoryUrl = try! FileManager().url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let fileUrl = documentsDirectoryUrl.appendingPathComponent("\(String(describing: self.googleUsersId)).png")
        
        do {
          try userImageData.write(to: fileUrl)
          print("Image was saved")
        } catch {
          print(error)
        }
      }
    }
  }
  
  func applicationWillResignActive(_ application: UIApplication) {
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
  }

  func applicationDidEnterBackground(_ application: UIApplication) {
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
  }

  func applicationWillEnterForeground(_ application: UIApplication) {
    // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
  }

  func applicationDidBecomeActive(_ application: UIApplication) {
    
  }

  func applicationWillTerminate(_ application: UIApplication) {
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    // Saves changes in the application's managed object context before the application terminates.
    self.saveContext()
  }

  // MARK: - Core Data stack

  lazy var persistentContainer: NSPersistentContainer = {
      // create / return container for appplication
      let container = NSPersistentContainer(name: "todolist")
      container.loadPersistentStores(completionHandler: { (storeDescription, error) in
          if let error = error as NSError? {
              // Replace this implementation with code to handle the error appropriately.
              // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
              fatalError("Unresolved error \(error), \(error.userInfo)")
          }
      })
      return container
  }()

  // MARK: - Core Data Saving support

  func saveContext () {
      let context = persistentContainer.viewContext
      if context.hasChanges {
          do {
              try context.save()
          } catch {
              // Replace this implementation with code to handle the error appropriately.
              // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
              let nserror = error as NSError
              fatalError("Unresolved error \(nserror), \(nserror.userInfo)")
          }
      }
  }
  
  static func shared() -> AppDelegate {
    return UIApplication.shared.delegate as! AppDelegate
  }

}


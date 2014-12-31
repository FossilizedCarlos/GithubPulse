//
//  ContentViewController.swift
//  GithubPulse
//
//  Created by Tadeu Zagallo on 12/28/14.
//  Copyright (c) 2014 Tadeu Zagallo. All rights reserved.
//

import Cocoa
import WebKit

class ContentViewController: NSViewController, NSXMLParserDelegate {
  @IBOutlet weak var webView:WebView?
  @IBOutlet weak var lastUpdate:NSTextField?
  
  var regex = NSRegularExpression(pattern: "^osx:(\\w+)\\((.*)\\)$", options: NSRegularExpressionOptions.CaseInsensitive, error: nil)
  var calls: [String: [String] -> Void]
  
  func loadCalls() {
    self.calls = [:]
    self.calls["contributions"] = { (args) in
      println("contributions", args)
      Contributions.fetch(args[0]) { (commits, streak, today) in
        let _ = self.webView?.stringByEvaluatingJavaScriptFromString("contributions(\(today),\(streak),\(commits))")
      }
    }
    
    self.calls["set"] = { (args) in
      println("set", args)
      NSUserDefaults.standardUserDefaults().setValue(args[1], forKey: args[0])
    }
    
    self.calls["get"] = { (args) in
      println("get", args)
      var value = NSUserDefaults.standardUserDefaults().valueForKey(args[0]) as String?
      
      if value == nil {
        value = ""
      }
      
      let key = args[0].stringByReplacingOccurrencesOfString("'", withString: "\\'", options: nil, range: nil)
      let v = value!.stringByReplacingOccurrencesOfString("'", withString: "\\'", options: nil, range: nil)
      
      self.webView?.stringByEvaluatingJavaScriptFromString("get('\(key)', '\(v)', \(args[1]))");
    }
    
    self.calls["remove"] = { (args) in
      println("remove", args)
      NSUserDefaults.standardUserDefaults().removeObjectForKey(args[0])
    }
    
    self.calls["check_login"] = { (args) in
      println("check_login", args)
      let active = NSBundle.mainBundle().isLoginItem()
      self.webView?.stringByEvaluatingJavaScriptFromString("raw('check_login', \(active))")
    }
    
    self.calls["toggle_login"] = { (args) in
      println("toggle_login", args)
      if NSBundle.mainBundle().isLoginItem() {
        NSBundle.mainBundle().removeFromLoginItems()
      } else {
        NSBundle.mainBundle().addToLoginItems()
      }
    }
    
    self.calls["quit"] = { (args) in
      println("quit", args)
      NSApplication.sharedApplication().terminate(self)
    }
  }
  
  override init() {
    self.calls = [:]
    super.init()
    self.loadCalls()
  }

  required init?(coder: NSCoder) {
    self.calls = [:]
    super.init(coder: coder)
    self.loadCalls()
  }
  
  override init?(nibName nibNameOrNil: String?, bundle nibBundleOrNil: NSBundle?) {
    self.calls = [:]
    super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    self.loadCalls()
  }
  
  override func viewDidLoad() {
    var indexPath = NSBundle.mainBundle().pathForResource("index", ofType: "html", inDirectory: "front")
#if DEBUG
    var url = NSURL(string: "http://localhost:8080")
#else
    var url = NSURL(fileURLWithPath: indexPath!)
#endif
    var request = NSURLRequest(URL: url!)
    
    self.webView!.policyDelegate = self;
    self.webView!.drawsBackground = false
    self.webView!.mainFrame.loadRequest(request)
    
    super.viewDidLoad()
  }
  
  @IBAction func refresh(sender: AnyObject?) {
    self.webView?.reload(sender)
  }
  
  override func webView(webView: WebView!, decidePolicyForNavigationAction actionInformation: [NSObject : AnyObject]!, request: NSURLRequest!, frame: WebFrame!, decisionListener listener: WebPolicyDecisionListener!) {
    var url:String = request.URL.absoluteString!.stringByReplacingPercentEscapesUsingEncoding(NSUTF8StringEncoding)!
    
    if url.hasPrefix("osx:") {
      let matches = self.regex?.matchesInString(url, options: nil, range: NSMakeRange(0, countElements(url)))
      let match = matches?[0] as NSTextCheckingResult
      
      let fn = (url as NSString).substringWithRange(match.rangeAtIndex(1))
      let args = (url as NSString).substringWithRange(match.rangeAtIndex(2)).componentsSeparatedByString("%%")
      
      let closure = self.calls[fn]
      closure?(args)
    } else if (url.hasPrefix("log:")) {
      println(url)
    } else {
      listener.use()
    }
  }
}
//
//  OpenSeaMapOverlay.swift
//  Open Sea Map Browser
//
//  Created by Hal Mueller on 8/17/15.
//  Copyright (c) 2015 Hal Mueller. All rights reserved.
//
//  After https://github.com/viggiosoft/MapTileOverlayTutorial

import Foundation
import MapKit

class OpenSeaMapOverlay: MKTileOverlay {
	private var operationQueue: NSOperationQueue = NSOperationQueue()
	var parentDirectory = "tilecache"
	
	init() {
		super.init(URLTemplate: "http://tiles.openseamap.org/seamark/{z}/{x}/{y}.png")
		self.minimumZ = 9
		self.maximumZ = 17
		self.canReplaceMapContent = false
		print("initialized")
		
		//		if (TARGET_IPHONE_SIMULATOR == 1) {
		let paths = NSSearchPathForDirectoriesInDomains(NSSearchPathDirectory.CachesDirectory, NSSearchPathDomainMask.UserDomainMask, true)
		let cachesDirectory : AnyObject = paths[0]
		print("Caches Directory is \(cachesDirectory)")
		//		}
	}
	
	override func loadTileAtPath(path: MKTileOverlayPath,
		result: ((NSData?, NSError?) -> Void)) {
			
			let parentYFolderURL = URLForTilecacheFolder().URLByAppendingPathComponent(self.cacheYFolderNameForPath(path))
			let tileFilePathURL = parentYFolderURL.URLByAppendingPathComponent(filePathForTile(path))
			let tileFilePath = tileFilePathURL.path!
			if NSFileManager.defaultManager().fileExistsAtPath(tileFilePath) {
				print("found \(tileFilePath)")
				let cachedData = NSData(contentsOfFile: tileFilePath)
				result(cachedData, nil)
			}
			else {
				let request = NSURLRequest(URL: self.URLForTilePath(path))
				//			println("\(request)")
				NSURLConnection.sendAsynchronousRequest(request, queue: operationQueue) { (response, data , error)  in
					if response != nil {
						let httpResponse = response as! NSHTTPURLResponse
						if httpResponse.statusCode == 200 {
							do {
								try NSFileManager.defaultManager().createDirectoryAtURL(parentYFolderURL,
									withIntermediateDirectories: true, attributes: nil)
							} catch _ {
							}
							let image: UIImage? = UIImage(data: data)
							if !data.writeToFile(tileFilePath, atomically: true) {
								dispatch_async(dispatch_get_main_queue(),
									{print("couldn't write \(tileFilePath)")})
							}
							result(data, error)
						}
						else {
							dispatch_async(dispatch_get_main_queue(),
								{print("response \(httpResponse.statusCode) \(request.URL)")})
						}
					}
				}
			}
	}
	
	// path to x.png, starting from cacheYFolderNameForPath
	private func filePathForTile(path: MKTileOverlayPath) -> String {
		_ = cacheYFolderNameForPath(path)
		return "/\(path.x).png"
	}
	
	// path to Y folder, starting from URLForTilecacheFolder
	private func cacheYFolderNameForPath(path: MKTileOverlayPath) -> String {
		return "\(path.contentScaleFactor)/\(path.z)/\(path.y)"
	}
	
	// folder within app's Library/Caches to use for this particular overlay
	private func URLForTilecacheFolder() -> NSURL {
		let URLForAppCacheFolder : NSURL = try! NSFileManager.defaultManager().URLForDirectory(NSSearchPathDirectory.CachesDirectory,
			inDomain: NSSearchPathDomainMask.UserDomainMask, appropriateForURL: nil, create: true)
		return URLForAppCacheFolder.URLByAppendingPathComponent(parentDirectory, isDirectory: true)
	}
	
	private func URLForYFolder(path: MKTileOverlayPath) -> NSURL {
		return URLForTilecacheFolder().URLByAppendingPathComponent(cacheYFolderNameForPath(path), isDirectory: true)
	}
	
	private func zcreateCacheFolderForPath(path: MKTileOverlayPath) {
		let tilePathString = cacheYFolderNameForPath(path)
		let tileURL = NSURL.fileURLWithPath(tilePathString)
		let URLForAppCacheFolder : NSURL? = try? NSFileManager.defaultManager().URLForDirectory(NSSearchPathDirectory.CachesDirectory,
			inDomain: NSSearchPathDomainMask.UserDomainMask, appropriateForURL: nil, create: true)
		if let URLForYFolder = URLForAppCacheFolder?.URLByAppendingPathComponent(tilePathString, isDirectory: true) {
			do {
				try NSFileManager.defaultManager().createDirectoryAtURL(URLForYFolder, withIntermediateDirectories: true, attributes: nil)
			} catch _ {
			}
			dispatch_async(dispatch_get_main_queue(), {print("should make \(URLForYFolder)")})
		}
		
	}
}

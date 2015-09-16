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
	let parentDirectory = "tilecache"
	let maximumCacheAge: NSTimeInterval = 30.0 * 24.0 * 60.0 * 60.0
	
	init() {
		super.init(URLTemplate: "http://tiles.openseamap.org/seamark/{z}/{x}/{y}.png")
		self.minimumZ = 9
		self.maximumZ = 17
		self.canReplaceMapContent = false
		
		
		#if (arch(i386) || arch(x86_64)) && os(iOS)
			let paths = NSSearchPathForDirectoriesInDomains(NSSearchPathDirectory.CachesDirectory, NSSearchPathDomainMask.UserDomainMask, true)
			let cachesDirectory : AnyObject = paths[0]
			print("Caches Directory is \(cachesDirectory)")
		#endif
	}
	
	override func loadTileAtPath(path: MKTileOverlayPath,
		result: ((NSData?, NSError?) -> Void)) {
			
			// MARK: This section feels very Unswiftie to me
			let parentXFolderURL = URLForTilecacheFolder().URLByAppendingPathComponent(self.cacheXFolderNameForPath(path))
			let tileFilePathURL = parentXFolderURL.URLByAppendingPathComponent(filePathForTile(path))
			let tileFilePath = tileFilePathURL.path!
			var useCachedVersion = false
			if NSFileManager.defaultManager().fileExistsAtPath(tileFilePath) {
				if let fileAttributes = try? NSFileManager.defaultManager().attributesOfItemAtPath(tileFilePath),
					fileModificationDate = fileAttributes[NSFileModificationDate] as? NSDate {
						if fileModificationDate.timeIntervalSinceNow > -1.0 * maximumCacheAge {
							useCachedVersion = true
						}
						else {
							print("too old")
						}
				}
			}
			if (useCachedVersion) {
				print("cached", tileFilePath)
				let cachedData = NSData(contentsOfFile: tileFilePath)
				result(cachedData, nil)
			}
			else {
				let request = NSURLRequest(URL: self.URLForTilePath(path))
				// TODO: switch to NSURLSession
				print("fetching", request)
				NSURLConnection.sendAsynchronousRequest(request, queue: operationQueue) { (response, data , error)  in
					if response != nil {
						let httpResponse = response as! NSHTTPURLResponse
						if httpResponse.statusCode == 200 {
							do {
								try NSFileManager.defaultManager().createDirectoryAtURL(parentXFolderURL,
									withIntermediateDirectories: true, attributes: nil)
							} catch {
								print("Couldn't create", parentXFolderURL, error)
							}
							if !data!.writeToFile(tileFilePath, atomically: true) {
								dispatch_async(dispatch_get_main_queue(),
									{print("couldn't write", tileFilePath)})
							}
							print("wrote", tileFilePath);
							result(data, error)
						}
						else {
							dispatch_async(dispatch_get_main_queue(),
								{
									print("response", httpResponse.statusCode, request.URL)
							})
						}
					}
				}
			}
	}
	
	// path to y.png, starting from cacheYFolderNameForPath
	private func filePathForTile(path: MKTileOverlayPath) -> String {
		print(cacheXFolderNameForPath(path))
		return "\(path.y).png"
	}
	
	// path to Y folder, starting from URLForTilecacheFolder
	private func cacheXFolderNameForPath(path: MKTileOverlayPath) -> String {
		return "\(path.contentScaleFactor)/\(path.z)/\(path.x)"
	}
	
	// folder within app's Library/Caches to use for this particular overlay
	private func URLForTilecacheFolder() -> NSURL {
		let URLForAppCacheFolder : NSURL = try! NSFileManager.defaultManager().URLForDirectory(NSSearchPathDirectory.CachesDirectory,
			inDomain: NSSearchPathDomainMask.UserDomainMask, appropriateForURL: nil, create: true)
		return URLForAppCacheFolder.URLByAppendingPathComponent(parentDirectory, isDirectory: true)
	}
	
	private func URLForXFolder(path: MKTileOverlayPath) -> NSURL {
		return URLForTilecacheFolder().URLByAppendingPathComponent(cacheXFolderNameForPath(path), isDirectory: true)
	}
}

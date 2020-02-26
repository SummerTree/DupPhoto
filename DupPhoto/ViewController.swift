//
//  ViewController.swift
//  DupPhoto
//
//  Created by Alex Chang (dragoonchang@gmail.com) on 2020/2/24.
//  Copyright © 2020 Alex Chang. All rights reserved.
//

import Cocoa

import Photos

class ViewController: NSViewController {
    var assetCollection: PHAssetCollection?
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        
        // this line does not work on macOS
        //PHPhotoLibrary.shared().register(self)

        PHPhotoLibrary.requestAuthorization({ (status: PHAuthorizationStatus) in
            if (status == PHAuthorizationStatus.authorized) {
                self.findDuplicateVideos()
            }
        });

    }

    func findDuplicateVideos() {
        // We generate new collection every time, append collection name with date string.
        let date = Date()
        let formatter = DateFormatter(); formatter.dateFormat = "yy.MM.dd hh:mm:ss"
        let dateStr = formatter.string(from: date)
        let albumTitle = "DupVideo \(dateStr)"

        // the container to keep record of all duplicate videos
        var collection: PHAsset

        // find the collection with specific title
        func fetchAssetCollectionForAlbumTitle() -> PHAssetCollection! {
            let fetchOptions = PHFetchOptions()
            fetchOptions.predicate = NSPredicate(format: "title = %@", albumTitle)
            let collection = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: fetchOptions)

            if let firstObject: AnyObject = collection.firstObject {
                return collection.firstObject as! PHAssetCollection
            }

            return nil
        }

        // create the collection we need, and find out the collection
        PHPhotoLibrary.shared().performChanges({
            PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: albumTitle)
        }, completionHandler: { success, error in
            if !success {
                print("Error creating album: \(String(describing: error)).")
                return
            }
            self.assetCollection = fetchAssetCollectionForAlbumTitle()
        })

        // find all videos and sort them by createDate asc
        let option = PHFetchOptions()
        //allPhotosOptions.predicate = [NSPredicate(predicateWithFormat: "mediaType != %d", argumentArray arguments: PHAssetMediaTypeVideo)];
        //var calendar = Calendar.current
        //calendar.timeZone = TimeZone.current
        //let predicate = NSPredicate(format: "creationDate > %@ AND creationDate < %@ AND mediaType == %i", currentDate.startOfDay as NSDate, currentDate.endOfDay as NSDate, PHAssetMediaType.video.rawValue)
        //let predicate = NSPredicate(format: "mediaType == %i", PHAssetMediaType.video.rawValue)
        //option.predicate = predicate
        let sort = NSSortDescriptor(key: "creationDate", ascending: true)
        option.sortDescriptors = [sort]
        let allVideos = PHAsset.fetchAssets(with: .video, options: option)

        print("allVideos.count: \(allVideos.count)")

        // If the fetch result isn't empty, proceed with the image request
        if allVideos.count == 0 {
            return
        }

        // The videos are sorted by creationDate asc, which I need is capture time, I don't know if there are same or not, so far so good.
        //
        var index = -1
        let maxSearch = 10
        var dupCount = 0
        var titles:NSMutableArray = []
        while (index < allVideos.count - 1) {
            index += 1
            let firstPHAsset = allVideos.object(at: index)

/*
            // I have problem to find out what I can use inside info, there is very few information on internet.
            // I just want to find the title of video, but not work now.
            let requestOptions = PHVideoRequestOptions() //; requestOptions.isSynchronous = true
            PHImageManager.default().requestAVAsset(forVideo: firstPHAsset, options: requestOptions,
                                                    resultHandler: { (avAsset, avAudio, info) in
                print(info)
                if info!.keys.contains(NSString(string:"PHImageFileURLKey")) {
                    let path = info![NSString(string: "PHImageFileURLKey")] as! NSURL
                    print(path)
                }
            })
*/

            // The original video file must be 1920x1080 or 1080x1920, we skip the smaller.
            print("* Video \(index):  width: \(firstPHAsset.pixelWidth), height: \(firstPHAsset.pixelHeight), duration:\(firstPHAsset.duration), title:\(firstPHAsset.localIdentifier)")
            if firstPHAsset.pixelHeight != 1080 && firstPHAsset.pixelWidth != 1080 {
                continue
            }

            // we skip short videos, because different videos have high chance on same length.
            let firstDuration = NSInteger (firstPHAsset.duration * 100)
            if (firstDuration < 500) {
                continue
            }

            // We search pre and post videos few videos (maxSearch), if they have orientation and same size, we count them the same.
            for i in -maxSearch...maxSearch {
                let secondIndex = index + i

                // we don't compare same file
                if secondIndex == index {
                    continue
                }

                // skip boundary outside 0...count
                if secondIndex <= 0 {
                    continue
                }

                // skip boundary outside 0...count
                if secondIndex >= allVideos.count {
                    continue
                }

                let secondPHAsset = allVideos.object(at: secondIndex)
                let secondDuration = NSInteger (secondPHAsset.duration * 100)
                if (firstPHAsset.pixelHeight / firstPHAsset.pixelWidth == secondPHAsset.pixelHeight / secondPHAsset.pixelWidth) && firstDuration == secondDuration {
                    dupCount += 1
                    print("* Video index \(index) maybe be the same with index \(secondIndex)")
                    print("* Video \(index):  width: \(firstPHAsset.pixelWidth), height: \(firstPHAsset.pixelHeight), duration:\(firstDuration)")
                    print("* Video \(secondIndex):  width: \(secondPHAsset.pixelWidth), height: \(secondPHAsset.pixelHeight), duration:\(secondDuration)")

                    // The most difficult part is those two lines inside PHPhotoLibrary.performChanges().
                    // There are very few document or article describe how to correctly deal the relationship of
                    // video and collection.
                    PHPhotoLibrary.shared().performChanges({
                        let changeRequest = PHAssetCollectionChangeRequest.init(for: self.assetCollection!)!
                        let result = changeRequest.addAssets([firstPHAsset, secondPHAsset] as NSArray)
                    })
                }
            }
        }

        print("* Dup count:\(dupCount)")

    }

    override var representedObject: Any? {
        didSet {
            // Update the view, if already loaded.
        }
    }
}


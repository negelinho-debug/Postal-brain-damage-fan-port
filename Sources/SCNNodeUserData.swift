
import Foundation
import SceneKit
import ObjectiveC

private var userDataKey: UInt8 = 0

extension SCNNode {
    var userData: NSMutableDictionary? {
        get {
            objc_getAssociatedObject(
                self,
                &userDataKey
            ) as? NSMutableDictionary
        }
        set {
            objc_setAssociatedObject(
                self,
                &userDataKey,
                newValue,
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
        }
    }
}

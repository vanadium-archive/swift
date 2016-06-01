// Copyright 2016 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import Foundation
import UIKit

class MemberView: UIView {
  var todoList: TodoList?

  func updateView() {
    // Remove all previous photos
    for view in subviews {
      view.removeFromSuperview()
    }
    if let list = todoList {
      var x: CGFloat = 0
      // Create and add a photo circle for all members
      for member in list.members {
        let profilePhoto = imageFactory(member.imageName, offset: x)
        insertSubview(profilePhoto, atIndex: 0)
        x += profilePhoto.frame.size.width - profilePhoto.frame.size.width * 0.25
      }
    }
  }

  func imageFactory(imageName: String, offset: CGFloat) -> UIImageView {
    let imageView = CircularImageView(image: UIImage(named: imageName))
    var frame = imageView.frame
    frame.size = CGSizeMake(self.frame.size.height, self.frame.size.height)
    frame.origin.x = offset
    imageView.frame = frame
    return imageView
  }

  override func layoutSubviews() {
    // Layout subviews is called often and possibly after creation (and auto layout adjustments),
    // so we need to adjust our view sizes to match
    let height = frame.size.height
    for view in subviews {
      view.frame.size = CGSizeMake(height, height)
    }
  }
}

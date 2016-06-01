// Copyright 2016 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import Foundation
import UIKit

@IBDesignable class CircularImageView: UIImageView {
  var borderColor: UIColor = UIColor.darkGrayColor()

  override func prepareForInterfaceBuilder() {
    setup()
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    // First point where autolayout frames have finished computation
    setup()
  }

  func setup() {
    layer.cornerRadius = frame.size.width * 0.5
    layer.borderWidth = 1
    layer.borderColor = borderColor.CGColor
  }

}
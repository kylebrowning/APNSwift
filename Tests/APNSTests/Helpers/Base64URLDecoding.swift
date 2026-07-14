//===----------------------------------------------------------------------===//
//
// This source file is part of the APNSwift open source project
//
// Copyright (c) 2022 the APNSwift project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of APNSwift project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import Foundation

/// Decodes a base64url-encoded (unpadded, `-`/`_` alphabet) string, as used in JWT segments.
///
/// This is a small test-only helper standing in for the vendored `Base64` decoder that used
/// to live in `APNSCore` — production code only ever needed base64 *encoding*, so the decode
/// half was removed. Tests that need to inspect the header/payload of a generated JWT can use
/// this instead.
func base64URLDecoded(_ string: String) -> Data? {
    var base64 = string
        .replacingOccurrences(of: "-", with: "+")
        .replacingOccurrences(of: "_", with: "/")

    let remainder = base64.count % 4
    if remainder > 0 {
        base64.append(contentsOf: String(repeating: "=", count: 4 - remainder))
    }

    return Data(base64Encoded: base64)
}

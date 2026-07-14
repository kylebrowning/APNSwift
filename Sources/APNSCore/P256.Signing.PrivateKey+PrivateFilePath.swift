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

import Crypto

extension P256.Signing.PrivateKey {
    @available(*, deprecated, message: "Use P256.Signing.PrivateKey(pemRepresentation:) instead.")
    public static func loadFrom(string: String) throws -> P256.Signing.PrivateKey {
        try .init(pemRepresentation: string)
    }
}

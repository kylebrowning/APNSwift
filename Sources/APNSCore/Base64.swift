//===----------------------------------------------------------------------===//
//
// This source file is part of the swift-extras-base64 open source project
//
// Copyright (c) 2022 the swift-extras-base64 project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

// This base64 implementation is heavily inspired by:

// https://github.com/lemire/fastbase64/blob/master/src/chromiumbase64.c
/*
 Copyright (c) 2015-2016, Wojciech Muła, Alfred Klomp,  Daniel Lemire
 (Unless otherwise stated in the source code)
 All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are
 met:

 1. Redistributions of source code must retain the above copyright
    notice, this list of conditions and the following disclaimer.

 2. Redistributions in binary form must reproduce the above copyright
    notice, this list of conditions and the following disclaimer in the
    documentation and/or other materials provided with the distribution.

 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS
 IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED
 TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A
 PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
 HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED
 TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
 PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
 LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
 NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

// https://github.com/client9/stringencoders/blob/master/src/modp_b64.c
/*
 The MIT License (MIT)

 Copyright (c) 2016 Nick Galbreath

 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in the Software without restriction, including without limitation the rights
 to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the Software is
 furnished to do so, subject to the following conditions:

 The above copyright notice and this permission notice shall be included in all
 copies or substantial portions of the Software.

 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 SOFTWARE.
 */

@usableFromInline
internal enum Base64 {}

// MARK: - Encoding -

extension Base64 {
    @usableFromInline
    internal struct EncodingOptions: OptionSet, Sendable {
        @usableFromInline
        internal let rawValue: UInt

        @inlinable
        internal init(rawValue: UInt) { self.rawValue = rawValue }

        @usableFromInline
        internal static let base64UrlAlphabet = EncodingOptions(rawValue: UInt(1 << 0))

        @usableFromInline
        internal static let omitPaddingCharacter = EncodingOptions(rawValue: UInt(1 << 1))
    }

    @usableFromInline
    internal static let encodePaddingCharacter: UInt8 = 61

    @usableFromInline
    static let encoding0: [UInt8] = [
        UInt8(ascii: "A"), UInt8(ascii: "A"), UInt8(ascii: "A"), UInt8(ascii: "A"), UInt8(ascii: "B"),
        UInt8(ascii: "B"),
        UInt8(ascii: "B"), UInt8(ascii: "B"), UInt8(ascii: "C"), UInt8(ascii: "C"),
        UInt8(ascii: "C"), UInt8(ascii: "C"), UInt8(ascii: "D"), UInt8(ascii: "D"), UInt8(ascii: "D"),
        UInt8(ascii: "D"),
        UInt8(ascii: "E"), UInt8(ascii: "E"), UInt8(ascii: "E"), UInt8(ascii: "E"),
        UInt8(ascii: "F"), UInt8(ascii: "F"), UInt8(ascii: "F"), UInt8(ascii: "F"), UInt8(ascii: "G"),
        UInt8(ascii: "G"),
        UInt8(ascii: "G"), UInt8(ascii: "G"), UInt8(ascii: "H"), UInt8(ascii: "H"),
        UInt8(ascii: "H"), UInt8(ascii: "H"), UInt8(ascii: "I"), UInt8(ascii: "I"), UInt8(ascii: "I"),
        UInt8(ascii: "I"),
        UInt8(ascii: "J"), UInt8(ascii: "J"), UInt8(ascii: "J"), UInt8(ascii: "J"),
        UInt8(ascii: "K"), UInt8(ascii: "K"), UInt8(ascii: "K"), UInt8(ascii: "K"), UInt8(ascii: "L"),
        UInt8(ascii: "L"),
        UInt8(ascii: "L"), UInt8(ascii: "L"), UInt8(ascii: "M"), UInt8(ascii: "M"),
        UInt8(ascii: "M"), UInt8(ascii: "M"), UInt8(ascii: "N"), UInt8(ascii: "N"), UInt8(ascii: "N"),
        UInt8(ascii: "N"),
        UInt8(ascii: "O"), UInt8(ascii: "O"), UInt8(ascii: "O"), UInt8(ascii: "O"),
        UInt8(ascii: "P"), UInt8(ascii: "P"), UInt8(ascii: "P"), UInt8(ascii: "P"), UInt8(ascii: "Q"),
        UInt8(ascii: "Q"),
        UInt8(ascii: "Q"), UInt8(ascii: "Q"), UInt8(ascii: "R"), UInt8(ascii: "R"),
        UInt8(ascii: "R"), UInt8(ascii: "R"), UInt8(ascii: "S"), UInt8(ascii: "S"), UInt8(ascii: "S"),
        UInt8(ascii: "S"),
        UInt8(ascii: "T"), UInt8(ascii: "T"), UInt8(ascii: "T"), UInt8(ascii: "T"),
        UInt8(ascii: "U"), UInt8(ascii: "U"), UInt8(ascii: "U"), UInt8(ascii: "U"), UInt8(ascii: "V"),
        UInt8(ascii: "V"),
        UInt8(ascii: "V"), UInt8(ascii: "V"), UInt8(ascii: "W"), UInt8(ascii: "W"),
        UInt8(ascii: "W"), UInt8(ascii: "W"), UInt8(ascii: "X"), UInt8(ascii: "X"), UInt8(ascii: "X"),
        UInt8(ascii: "X"),
        UInt8(ascii: "Y"), UInt8(ascii: "Y"), UInt8(ascii: "Y"), UInt8(ascii: "Y"),
        UInt8(ascii: "Z"), UInt8(ascii: "Z"), UInt8(ascii: "Z"), UInt8(ascii: "Z"), UInt8(ascii: "a"),
        UInt8(ascii: "a"),
        UInt8(ascii: "a"), UInt8(ascii: "a"), UInt8(ascii: "b"), UInt8(ascii: "b"),
        UInt8(ascii: "b"), UInt8(ascii: "b"), UInt8(ascii: "c"), UInt8(ascii: "c"), UInt8(ascii: "c"),
        UInt8(ascii: "c"),
        UInt8(ascii: "d"), UInt8(ascii: "d"), UInt8(ascii: "d"), UInt8(ascii: "d"),
        UInt8(ascii: "e"), UInt8(ascii: "e"), UInt8(ascii: "e"), UInt8(ascii: "e"), UInt8(ascii: "f"),
        UInt8(ascii: "f"),
        UInt8(ascii: "f"), UInt8(ascii: "f"), UInt8(ascii: "g"), UInt8(ascii: "g"),
        UInt8(ascii: "g"), UInt8(ascii: "g"), UInt8(ascii: "h"), UInt8(ascii: "h"), UInt8(ascii: "h"),
        UInt8(ascii: "h"),
        UInt8(ascii: "i"), UInt8(ascii: "i"), UInt8(ascii: "i"), UInt8(ascii: "i"),
        UInt8(ascii: "j"), UInt8(ascii: "j"), UInt8(ascii: "j"), UInt8(ascii: "j"), UInt8(ascii: "k"),
        UInt8(ascii: "k"),
        UInt8(ascii: "k"), UInt8(ascii: "k"), UInt8(ascii: "l"), UInt8(ascii: "l"),
        UInt8(ascii: "l"), UInt8(ascii: "l"), UInt8(ascii: "m"), UInt8(ascii: "m"), UInt8(ascii: "m"),
        UInt8(ascii: "m"),
        UInt8(ascii: "n"), UInt8(ascii: "n"), UInt8(ascii: "n"), UInt8(ascii: "n"),
        UInt8(ascii: "o"), UInt8(ascii: "o"), UInt8(ascii: "o"), UInt8(ascii: "o"), UInt8(ascii: "p"),
        UInt8(ascii: "p"),
        UInt8(ascii: "p"), UInt8(ascii: "p"), UInt8(ascii: "q"), UInt8(ascii: "q"),
        UInt8(ascii: "q"), UInt8(ascii: "q"), UInt8(ascii: "r"), UInt8(ascii: "r"), UInt8(ascii: "r"),
        UInt8(ascii: "r"),
        UInt8(ascii: "s"), UInt8(ascii: "s"), UInt8(ascii: "s"), UInt8(ascii: "s"),
        UInt8(ascii: "t"), UInt8(ascii: "t"), UInt8(ascii: "t"), UInt8(ascii: "t"), UInt8(ascii: "u"),
        UInt8(ascii: "u"),
        UInt8(ascii: "u"), UInt8(ascii: "u"), UInt8(ascii: "v"), UInt8(ascii: "v"),
        UInt8(ascii: "v"), UInt8(ascii: "v"), UInt8(ascii: "w"), UInt8(ascii: "w"), UInt8(ascii: "w"),
        UInt8(ascii: "w"),
        UInt8(ascii: "x"), UInt8(ascii: "x"), UInt8(ascii: "x"), UInt8(ascii: "x"),
        UInt8(ascii: "y"), UInt8(ascii: "y"), UInt8(ascii: "y"), UInt8(ascii: "y"), UInt8(ascii: "z"),
        UInt8(ascii: "z"),
        UInt8(ascii: "z"), UInt8(ascii: "z"), UInt8(ascii: "0"), UInt8(ascii: "0"),
        UInt8(ascii: "0"), UInt8(ascii: "0"), UInt8(ascii: "1"), UInt8(ascii: "1"), UInt8(ascii: "1"),
        UInt8(ascii: "1"),
        UInt8(ascii: "2"), UInt8(ascii: "2"), UInt8(ascii: "2"), UInt8(ascii: "2"),
        UInt8(ascii: "3"), UInt8(ascii: "3"), UInt8(ascii: "3"), UInt8(ascii: "3"), UInt8(ascii: "4"),
        UInt8(ascii: "4"),
        UInt8(ascii: "4"), UInt8(ascii: "4"), UInt8(ascii: "5"), UInt8(ascii: "5"),
        UInt8(ascii: "5"), UInt8(ascii: "5"), UInt8(ascii: "6"), UInt8(ascii: "6"), UInt8(ascii: "6"),
        UInt8(ascii: "6"),
        UInt8(ascii: "7"), UInt8(ascii: "7"), UInt8(ascii: "7"), UInt8(ascii: "7"),
        UInt8(ascii: "8"), UInt8(ascii: "8"), UInt8(ascii: "8"), UInt8(ascii: "8"), UInt8(ascii: "9"),
        UInt8(ascii: "9"),
        UInt8(ascii: "9"), UInt8(ascii: "9"), UInt8(ascii: "+"), UInt8(ascii: "+"),
        UInt8(ascii: "+"), UInt8(ascii: "+"), UInt8(ascii: "/"), UInt8(ascii: "/"), UInt8(ascii: "/"),
        UInt8(ascii: "/"),
    ]

    @usableFromInline
    static let encoding1: [UInt8] = [
        UInt8(ascii: "A"), UInt8(ascii: "B"), UInt8(ascii: "C"), UInt8(ascii: "D"), UInt8(ascii: "E"),
        UInt8(ascii: "F"),
        UInt8(ascii: "G"), UInt8(ascii: "H"), UInt8(ascii: "I"), UInt8(ascii: "J"),
        UInt8(ascii: "K"), UInt8(ascii: "L"), UInt8(ascii: "M"), UInt8(ascii: "N"), UInt8(ascii: "O"),
        UInt8(ascii: "P"),
        UInt8(ascii: "Q"), UInt8(ascii: "R"), UInt8(ascii: "S"), UInt8(ascii: "T"),
        UInt8(ascii: "U"), UInt8(ascii: "V"), UInt8(ascii: "W"), UInt8(ascii: "X"), UInt8(ascii: "Y"),
        UInt8(ascii: "Z"),
        UInt8(ascii: "a"), UInt8(ascii: "b"), UInt8(ascii: "c"), UInt8(ascii: "d"),
        UInt8(ascii: "e"), UInt8(ascii: "f"), UInt8(ascii: "g"), UInt8(ascii: "h"), UInt8(ascii: "i"),
        UInt8(ascii: "j"),
        UInt8(ascii: "k"), UInt8(ascii: "l"), UInt8(ascii: "m"), UInt8(ascii: "n"),
        UInt8(ascii: "o"), UInt8(ascii: "p"), UInt8(ascii: "q"), UInt8(ascii: "r"), UInt8(ascii: "s"),
        UInt8(ascii: "t"),
        UInt8(ascii: "u"), UInt8(ascii: "v"), UInt8(ascii: "w"), UInt8(ascii: "x"),
        UInt8(ascii: "y"), UInt8(ascii: "z"), UInt8(ascii: "0"), UInt8(ascii: "1"), UInt8(ascii: "2"),
        UInt8(ascii: "3"),
        UInt8(ascii: "4"), UInt8(ascii: "5"), UInt8(ascii: "6"), UInt8(ascii: "7"),
        UInt8(ascii: "8"), UInt8(ascii: "9"), UInt8(ascii: "+"), UInt8(ascii: "/"), UInt8(ascii: "A"),
        UInt8(ascii: "B"),
        UInt8(ascii: "C"), UInt8(ascii: "D"), UInt8(ascii: "E"), UInt8(ascii: "F"),
        UInt8(ascii: "G"), UInt8(ascii: "H"), UInt8(ascii: "I"), UInt8(ascii: "J"), UInt8(ascii: "K"),
        UInt8(ascii: "L"),
        UInt8(ascii: "M"), UInt8(ascii: "N"), UInt8(ascii: "O"), UInt8(ascii: "P"),
        UInt8(ascii: "Q"), UInt8(ascii: "R"), UInt8(ascii: "S"), UInt8(ascii: "T"), UInt8(ascii: "U"),
        UInt8(ascii: "V"),
        UInt8(ascii: "W"), UInt8(ascii: "X"), UInt8(ascii: "Y"), UInt8(ascii: "Z"),
        UInt8(ascii: "a"), UInt8(ascii: "b"), UInt8(ascii: "c"), UInt8(ascii: "d"), UInt8(ascii: "e"),
        UInt8(ascii: "f"),
        UInt8(ascii: "g"), UInt8(ascii: "h"), UInt8(ascii: "i"), UInt8(ascii: "j"),
        UInt8(ascii: "k"), UInt8(ascii: "l"), UInt8(ascii: "m"), UInt8(ascii: "n"), UInt8(ascii: "o"),
        UInt8(ascii: "p"),
        UInt8(ascii: "q"), UInt8(ascii: "r"), UInt8(ascii: "s"), UInt8(ascii: "t"),
        UInt8(ascii: "u"), UInt8(ascii: "v"), UInt8(ascii: "w"), UInt8(ascii: "x"), UInt8(ascii: "y"),
        UInt8(ascii: "z"),
        UInt8(ascii: "0"), UInt8(ascii: "1"), UInt8(ascii: "2"), UInt8(ascii: "3"),
        UInt8(ascii: "4"), UInt8(ascii: "5"), UInt8(ascii: "6"), UInt8(ascii: "7"), UInt8(ascii: "8"),
        UInt8(ascii: "9"),
        UInt8(ascii: "+"), UInt8(ascii: "/"), UInt8(ascii: "A"), UInt8(ascii: "B"),
        UInt8(ascii: "C"), UInt8(ascii: "D"), UInt8(ascii: "E"), UInt8(ascii: "F"), UInt8(ascii: "G"),
        UInt8(ascii: "H"),
        UInt8(ascii: "I"), UInt8(ascii: "J"), UInt8(ascii: "K"), UInt8(ascii: "L"),
        UInt8(ascii: "M"), UInt8(ascii: "N"), UInt8(ascii: "O"), UInt8(ascii: "P"), UInt8(ascii: "Q"),
        UInt8(ascii: "R"),
        UInt8(ascii: "S"), UInt8(ascii: "T"), UInt8(ascii: "U"), UInt8(ascii: "V"),
        UInt8(ascii: "W"), UInt8(ascii: "X"), UInt8(ascii: "Y"), UInt8(ascii: "Z"), UInt8(ascii: "a"),
        UInt8(ascii: "b"),
        UInt8(ascii: "c"), UInt8(ascii: "d"), UInt8(ascii: "e"), UInt8(ascii: "f"),
        UInt8(ascii: "g"), UInt8(ascii: "h"), UInt8(ascii: "i"), UInt8(ascii: "j"), UInt8(ascii: "k"),
        UInt8(ascii: "l"),
        UInt8(ascii: "m"), UInt8(ascii: "n"), UInt8(ascii: "o"), UInt8(ascii: "p"),
        UInt8(ascii: "q"), UInt8(ascii: "r"), UInt8(ascii: "s"), UInt8(ascii: "t"), UInt8(ascii: "u"),
        UInt8(ascii: "v"),
        UInt8(ascii: "w"), UInt8(ascii: "x"), UInt8(ascii: "y"), UInt8(ascii: "z"),
        UInt8(ascii: "0"), UInt8(ascii: "1"), UInt8(ascii: "2"), UInt8(ascii: "3"), UInt8(ascii: "4"),
        UInt8(ascii: "5"),
        UInt8(ascii: "6"), UInt8(ascii: "7"), UInt8(ascii: "8"), UInt8(ascii: "9"),
        UInt8(ascii: "+"), UInt8(ascii: "/"), UInt8(ascii: "A"), UInt8(ascii: "B"), UInt8(ascii: "C"),
        UInt8(ascii: "D"),
        UInt8(ascii: "E"), UInt8(ascii: "F"), UInt8(ascii: "G"), UInt8(ascii: "H"),
        UInt8(ascii: "I"), UInt8(ascii: "J"), UInt8(ascii: "K"), UInt8(ascii: "L"), UInt8(ascii: "M"),
        UInt8(ascii: "N"),
        UInt8(ascii: "O"), UInt8(ascii: "P"), UInt8(ascii: "Q"), UInt8(ascii: "R"),
        UInt8(ascii: "S"), UInt8(ascii: "T"), UInt8(ascii: "U"), UInt8(ascii: "V"), UInt8(ascii: "W"),
        UInt8(ascii: "X"),
        UInt8(ascii: "Y"), UInt8(ascii: "Z"), UInt8(ascii: "a"), UInt8(ascii: "b"),
        UInt8(ascii: "c"), UInt8(ascii: "d"), UInt8(ascii: "e"), UInt8(ascii: "f"), UInt8(ascii: "g"),
        UInt8(ascii: "h"),
        UInt8(ascii: "i"), UInt8(ascii: "j"), UInt8(ascii: "k"), UInt8(ascii: "l"),
        UInt8(ascii: "m"), UInt8(ascii: "n"), UInt8(ascii: "o"), UInt8(ascii: "p"), UInt8(ascii: "q"),
        UInt8(ascii: "r"),
        UInt8(ascii: "s"), UInt8(ascii: "t"), UInt8(ascii: "u"), UInt8(ascii: "v"),
        UInt8(ascii: "w"), UInt8(ascii: "x"), UInt8(ascii: "y"), UInt8(ascii: "z"), UInt8(ascii: "0"),
        UInt8(ascii: "1"),
        UInt8(ascii: "2"), UInt8(ascii: "3"), UInt8(ascii: "4"), UInt8(ascii: "5"),
        UInt8(ascii: "6"), UInt8(ascii: "7"), UInt8(ascii: "8"), UInt8(ascii: "9"), UInt8(ascii: "+"),
        UInt8(ascii: "/"),
    ]

    @usableFromInline
    static let encoding0url: [UInt8] = [
        UInt8(ascii: "A"), UInt8(ascii: "A"), UInt8(ascii: "A"), UInt8(ascii: "A"), UInt8(ascii: "B"),
        UInt8(ascii: "B"),
        UInt8(ascii: "B"), UInt8(ascii: "B"), UInt8(ascii: "C"), UInt8(ascii: "C"),
        UInt8(ascii: "C"), UInt8(ascii: "C"), UInt8(ascii: "D"), UInt8(ascii: "D"), UInt8(ascii: "D"),
        UInt8(ascii: "D"),
        UInt8(ascii: "E"), UInt8(ascii: "E"), UInt8(ascii: "E"), UInt8(ascii: "E"),
        UInt8(ascii: "F"), UInt8(ascii: "F"), UInt8(ascii: "F"), UInt8(ascii: "F"), UInt8(ascii: "G"),
        UInt8(ascii: "G"),
        UInt8(ascii: "G"), UInt8(ascii: "G"), UInt8(ascii: "H"), UInt8(ascii: "H"),
        UInt8(ascii: "H"), UInt8(ascii: "H"), UInt8(ascii: "I"), UInt8(ascii: "I"), UInt8(ascii: "I"),
        UInt8(ascii: "I"),
        UInt8(ascii: "J"), UInt8(ascii: "J"), UInt8(ascii: "J"), UInt8(ascii: "J"),
        UInt8(ascii: "K"), UInt8(ascii: "K"), UInt8(ascii: "K"), UInt8(ascii: "K"), UInt8(ascii: "L"),
        UInt8(ascii: "L"),
        UInt8(ascii: "L"), UInt8(ascii: "L"), UInt8(ascii: "M"), UInt8(ascii: "M"),
        UInt8(ascii: "M"), UInt8(ascii: "M"), UInt8(ascii: "N"), UInt8(ascii: "N"), UInt8(ascii: "N"),
        UInt8(ascii: "N"),
        UInt8(ascii: "O"), UInt8(ascii: "O"), UInt8(ascii: "O"), UInt8(ascii: "O"),
        UInt8(ascii: "P"), UInt8(ascii: "P"), UInt8(ascii: "P"), UInt8(ascii: "P"), UInt8(ascii: "Q"),
        UInt8(ascii: "Q"),
        UInt8(ascii: "Q"), UInt8(ascii: "Q"), UInt8(ascii: "R"), UInt8(ascii: "R"),
        UInt8(ascii: "R"), UInt8(ascii: "R"), UInt8(ascii: "S"), UInt8(ascii: "S"), UInt8(ascii: "S"),
        UInt8(ascii: "S"),
        UInt8(ascii: "T"), UInt8(ascii: "T"), UInt8(ascii: "T"), UInt8(ascii: "T"),
        UInt8(ascii: "U"), UInt8(ascii: "U"), UInt8(ascii: "U"), UInt8(ascii: "U"), UInt8(ascii: "V"),
        UInt8(ascii: "V"),
        UInt8(ascii: "V"), UInt8(ascii: "V"), UInt8(ascii: "W"), UInt8(ascii: "W"),
        UInt8(ascii: "W"), UInt8(ascii: "W"), UInt8(ascii: "X"), UInt8(ascii: "X"), UInt8(ascii: "X"),
        UInt8(ascii: "X"),
        UInt8(ascii: "Y"), UInt8(ascii: "Y"), UInt8(ascii: "Y"), UInt8(ascii: "Y"),
        UInt8(ascii: "Z"), UInt8(ascii: "Z"), UInt8(ascii: "Z"), UInt8(ascii: "Z"), UInt8(ascii: "a"),
        UInt8(ascii: "a"),
        UInt8(ascii: "a"), UInt8(ascii: "a"), UInt8(ascii: "b"), UInt8(ascii: "b"),
        UInt8(ascii: "b"), UInt8(ascii: "b"), UInt8(ascii: "c"), UInt8(ascii: "c"), UInt8(ascii: "c"),
        UInt8(ascii: "c"),
        UInt8(ascii: "d"), UInt8(ascii: "d"), UInt8(ascii: "d"), UInt8(ascii: "d"),
        UInt8(ascii: "e"), UInt8(ascii: "e"), UInt8(ascii: "e"), UInt8(ascii: "e"), UInt8(ascii: "f"),
        UInt8(ascii: "f"),
        UInt8(ascii: "f"), UInt8(ascii: "f"), UInt8(ascii: "g"), UInt8(ascii: "g"),
        UInt8(ascii: "g"), UInt8(ascii: "g"), UInt8(ascii: "h"), UInt8(ascii: "h"), UInt8(ascii: "h"),
        UInt8(ascii: "h"),
        UInt8(ascii: "i"), UInt8(ascii: "i"), UInt8(ascii: "i"), UInt8(ascii: "i"),
        UInt8(ascii: "j"), UInt8(ascii: "j"), UInt8(ascii: "j"), UInt8(ascii: "j"), UInt8(ascii: "k"),
        UInt8(ascii: "k"),
        UInt8(ascii: "k"), UInt8(ascii: "k"), UInt8(ascii: "l"), UInt8(ascii: "l"),
        UInt8(ascii: "l"), UInt8(ascii: "l"), UInt8(ascii: "m"), UInt8(ascii: "m"), UInt8(ascii: "m"),
        UInt8(ascii: "m"),
        UInt8(ascii: "n"), UInt8(ascii: "n"), UInt8(ascii: "n"), UInt8(ascii: "n"),
        UInt8(ascii: "o"), UInt8(ascii: "o"), UInt8(ascii: "o"), UInt8(ascii: "o"), UInt8(ascii: "p"),
        UInt8(ascii: "p"),
        UInt8(ascii: "p"), UInt8(ascii: "p"), UInt8(ascii: "q"), UInt8(ascii: "q"),
        UInt8(ascii: "q"), UInt8(ascii: "q"), UInt8(ascii: "r"), UInt8(ascii: "r"), UInt8(ascii: "r"),
        UInt8(ascii: "r"),
        UInt8(ascii: "s"), UInt8(ascii: "s"), UInt8(ascii: "s"), UInt8(ascii: "s"),
        UInt8(ascii: "t"), UInt8(ascii: "t"), UInt8(ascii: "t"), UInt8(ascii: "t"), UInt8(ascii: "u"),
        UInt8(ascii: "u"),
        UInt8(ascii: "u"), UInt8(ascii: "u"), UInt8(ascii: "v"), UInt8(ascii: "v"),
        UInt8(ascii: "v"), UInt8(ascii: "v"), UInt8(ascii: "w"), UInt8(ascii: "w"), UInt8(ascii: "w"),
        UInt8(ascii: "w"),
        UInt8(ascii: "x"), UInt8(ascii: "x"), UInt8(ascii: "x"), UInt8(ascii: "x"),
        UInt8(ascii: "y"), UInt8(ascii: "y"), UInt8(ascii: "y"), UInt8(ascii: "y"), UInt8(ascii: "z"),
        UInt8(ascii: "z"),
        UInt8(ascii: "z"), UInt8(ascii: "z"), UInt8(ascii: "0"), UInt8(ascii: "0"),
        UInt8(ascii: "0"), UInt8(ascii: "0"), UInt8(ascii: "1"), UInt8(ascii: "1"), UInt8(ascii: "1"),
        UInt8(ascii: "1"),
        UInt8(ascii: "2"), UInt8(ascii: "2"), UInt8(ascii: "2"), UInt8(ascii: "2"),
        UInt8(ascii: "3"), UInt8(ascii: "3"), UInt8(ascii: "3"), UInt8(ascii: "3"), UInt8(ascii: "4"),
        UInt8(ascii: "4"),
        UInt8(ascii: "4"), UInt8(ascii: "4"), UInt8(ascii: "5"), UInt8(ascii: "5"),
        UInt8(ascii: "5"), UInt8(ascii: "5"), UInt8(ascii: "6"), UInt8(ascii: "6"), UInt8(ascii: "6"),
        UInt8(ascii: "6"),
        UInt8(ascii: "7"), UInt8(ascii: "7"), UInt8(ascii: "7"), UInt8(ascii: "7"),
        UInt8(ascii: "8"), UInt8(ascii: "8"), UInt8(ascii: "8"), UInt8(ascii: "8"), UInt8(ascii: "9"),
        UInt8(ascii: "9"),
        UInt8(ascii: "9"), UInt8(ascii: "9"), UInt8(ascii: "-"), UInt8(ascii: "-"),
        UInt8(ascii: "-"), UInt8(ascii: "-"), UInt8(ascii: "_"), UInt8(ascii: "_"), UInt8(ascii: "_"),
        UInt8(ascii: "_"),
    ]

    @usableFromInline
    static let encoding1url: [UInt8] = [
        UInt8(ascii: "A"), UInt8(ascii: "B"), UInt8(ascii: "C"), UInt8(ascii: "D"), UInt8(ascii: "E"),
        UInt8(ascii: "F"),
        UInt8(ascii: "G"), UInt8(ascii: "H"), UInt8(ascii: "I"), UInt8(ascii: "J"),
        UInt8(ascii: "K"), UInt8(ascii: "L"), UInt8(ascii: "M"), UInt8(ascii: "N"), UInt8(ascii: "O"),
        UInt8(ascii: "P"),
        UInt8(ascii: "Q"), UInt8(ascii: "R"), UInt8(ascii: "S"), UInt8(ascii: "T"),
        UInt8(ascii: "U"), UInt8(ascii: "V"), UInt8(ascii: "W"), UInt8(ascii: "X"), UInt8(ascii: "Y"),
        UInt8(ascii: "Z"),
        UInt8(ascii: "a"), UInt8(ascii: "b"), UInt8(ascii: "c"), UInt8(ascii: "d"),
        UInt8(ascii: "e"), UInt8(ascii: "f"), UInt8(ascii: "g"), UInt8(ascii: "h"), UInt8(ascii: "i"),
        UInt8(ascii: "j"),
        UInt8(ascii: "k"), UInt8(ascii: "l"), UInt8(ascii: "m"), UInt8(ascii: "n"),
        UInt8(ascii: "o"), UInt8(ascii: "p"), UInt8(ascii: "q"), UInt8(ascii: "r"), UInt8(ascii: "s"),
        UInt8(ascii: "t"),
        UInt8(ascii: "u"), UInt8(ascii: "v"), UInt8(ascii: "w"), UInt8(ascii: "x"),
        UInt8(ascii: "y"), UInt8(ascii: "z"), UInt8(ascii: "0"), UInt8(ascii: "1"), UInt8(ascii: "2"),
        UInt8(ascii: "3"),
        UInt8(ascii: "4"), UInt8(ascii: "5"), UInt8(ascii: "6"), UInt8(ascii: "7"),
        UInt8(ascii: "8"), UInt8(ascii: "9"), UInt8(ascii: "-"), UInt8(ascii: "_"), UInt8(ascii: "A"),
        UInt8(ascii: "B"),
        UInt8(ascii: "C"), UInt8(ascii: "D"), UInt8(ascii: "E"), UInt8(ascii: "F"),
        UInt8(ascii: "G"), UInt8(ascii: "H"), UInt8(ascii: "I"), UInt8(ascii: "J"), UInt8(ascii: "K"),
        UInt8(ascii: "L"),
        UInt8(ascii: "M"), UInt8(ascii: "N"), UInt8(ascii: "O"), UInt8(ascii: "P"),
        UInt8(ascii: "Q"), UInt8(ascii: "R"), UInt8(ascii: "S"), UInt8(ascii: "T"), UInt8(ascii: "U"),
        UInt8(ascii: "V"),
        UInt8(ascii: "W"), UInt8(ascii: "X"), UInt8(ascii: "Y"), UInt8(ascii: "Z"),
        UInt8(ascii: "a"), UInt8(ascii: "b"), UInt8(ascii: "c"), UInt8(ascii: "d"), UInt8(ascii: "e"),
        UInt8(ascii: "f"),
        UInt8(ascii: "g"), UInt8(ascii: "h"), UInt8(ascii: "i"), UInt8(ascii: "j"),
        UInt8(ascii: "k"), UInt8(ascii: "l"), UInt8(ascii: "m"), UInt8(ascii: "n"), UInt8(ascii: "o"),
        UInt8(ascii: "p"),
        UInt8(ascii: "q"), UInt8(ascii: "r"), UInt8(ascii: "s"), UInt8(ascii: "t"),
        UInt8(ascii: "u"), UInt8(ascii: "v"), UInt8(ascii: "w"), UInt8(ascii: "x"), UInt8(ascii: "y"),
        UInt8(ascii: "z"),
        UInt8(ascii: "0"), UInt8(ascii: "1"), UInt8(ascii: "2"), UInt8(ascii: "3"),
        UInt8(ascii: "4"), UInt8(ascii: "5"), UInt8(ascii: "6"), UInt8(ascii: "7"), UInt8(ascii: "8"),
        UInt8(ascii: "9"),
        UInt8(ascii: "-"), UInt8(ascii: "_"), UInt8(ascii: "A"), UInt8(ascii: "B"),
        UInt8(ascii: "C"), UInt8(ascii: "D"), UInt8(ascii: "E"), UInt8(ascii: "F"), UInt8(ascii: "G"),
        UInt8(ascii: "H"),
        UInt8(ascii: "I"), UInt8(ascii: "J"), UInt8(ascii: "K"), UInt8(ascii: "L"),
        UInt8(ascii: "M"), UInt8(ascii: "N"), UInt8(ascii: "O"), UInt8(ascii: "P"), UInt8(ascii: "Q"),
        UInt8(ascii: "R"),
        UInt8(ascii: "S"), UInt8(ascii: "T"), UInt8(ascii: "U"), UInt8(ascii: "V"),
        UInt8(ascii: "W"), UInt8(ascii: "X"), UInt8(ascii: "Y"), UInt8(ascii: "Z"), UInt8(ascii: "a"),
        UInt8(ascii: "b"),
        UInt8(ascii: "c"), UInt8(ascii: "d"), UInt8(ascii: "e"), UInt8(ascii: "f"),
        UInt8(ascii: "g"), UInt8(ascii: "h"), UInt8(ascii: "i"), UInt8(ascii: "j"), UInt8(ascii: "k"),
        UInt8(ascii: "l"),
        UInt8(ascii: "m"), UInt8(ascii: "n"), UInt8(ascii: "o"), UInt8(ascii: "p"),
        UInt8(ascii: "q"), UInt8(ascii: "r"), UInt8(ascii: "s"), UInt8(ascii: "t"), UInt8(ascii: "u"),
        UInt8(ascii: "v"),
        UInt8(ascii: "w"), UInt8(ascii: "x"), UInt8(ascii: "y"), UInt8(ascii: "z"),
        UInt8(ascii: "0"), UInt8(ascii: "1"), UInt8(ascii: "2"), UInt8(ascii: "3"), UInt8(ascii: "4"),
        UInt8(ascii: "5"),
        UInt8(ascii: "6"), UInt8(ascii: "7"), UInt8(ascii: "8"), UInt8(ascii: "9"),
        UInt8(ascii: "-"), UInt8(ascii: "_"), UInt8(ascii: "A"), UInt8(ascii: "B"), UInt8(ascii: "C"),
        UInt8(ascii: "D"),
        UInt8(ascii: "E"), UInt8(ascii: "F"), UInt8(ascii: "G"), UInt8(ascii: "H"),
        UInt8(ascii: "I"), UInt8(ascii: "J"), UInt8(ascii: "K"), UInt8(ascii: "L"), UInt8(ascii: "M"),
        UInt8(ascii: "N"),
        UInt8(ascii: "O"), UInt8(ascii: "P"), UInt8(ascii: "Q"), UInt8(ascii: "R"),
        UInt8(ascii: "S"), UInt8(ascii: "T"), UInt8(ascii: "U"), UInt8(ascii: "V"), UInt8(ascii: "W"),
        UInt8(ascii: "X"),
        UInt8(ascii: "Y"), UInt8(ascii: "Z"), UInt8(ascii: "a"), UInt8(ascii: "b"),
        UInt8(ascii: "c"), UInt8(ascii: "d"), UInt8(ascii: "e"), UInt8(ascii: "f"), UInt8(ascii: "g"),
        UInt8(ascii: "h"),
        UInt8(ascii: "i"), UInt8(ascii: "j"), UInt8(ascii: "k"), UInt8(ascii: "l"),
        UInt8(ascii: "m"), UInt8(ascii: "n"), UInt8(ascii: "o"), UInt8(ascii: "p"), UInt8(ascii: "q"),
        UInt8(ascii: "r"),
        UInt8(ascii: "s"), UInt8(ascii: "t"), UInt8(ascii: "u"), UInt8(ascii: "v"),
        UInt8(ascii: "w"), UInt8(ascii: "x"), UInt8(ascii: "y"), UInt8(ascii: "z"), UInt8(ascii: "0"),
        UInt8(ascii: "1"),
        UInt8(ascii: "2"), UInt8(ascii: "3"), UInt8(ascii: "4"), UInt8(ascii: "5"),
        UInt8(ascii: "6"), UInt8(ascii: "7"), UInt8(ascii: "8"), UInt8(ascii: "9"), UInt8(ascii: "-"),
        UInt8(ascii: "_"),
    ]

    @inlinable
    internal static func encodeBytes<Buffer: Collection>(bytes: Buffer, options: EncodingOptions = [])
        -> [UInt8] where Buffer.Element == UInt8 {
        let newCapacity = ((bytes.count + 2) / 3) * 4

        if let result = bytes.withContiguousStorageIfAvailable({ input -> [UInt8] in
            [UInt8](unsafeUninitializedCapacity: newCapacity) { buffer, length in
                Self._encodeChromium(input: input, buffer: buffer, length: &length, options: options)
            }
        }) {
            return result
        }

        return self.encodeBytes(bytes: Array(bytes), options: options)
    }

    @inlinable
    static func _encodeChromium(
        input: UnsafeBufferPointer<UInt8>,
        buffer: UnsafeMutableBufferPointer<UInt8>,
        length: inout Int,
        options: EncodingOptions
    ) {
        let omitPaddingCharacter = options.contains(.omitPaddingCharacter)

        Self.withUnsafeEncodingTablesAsBufferPointers(options: options) { e0, e1 in
            let to = input.count / 3 * 3
            var outIndex = 0
            for index in stride(from: 0, to: to, by: 3) {
                let i1 = input[index]
                let i2 = input[index + 1]
                let i3 = input[index + 2]
                buffer[outIndex] = e0[Int(i1)]
                buffer[outIndex + 1] = e1[Int(((i1 & 0x03) << 4) | ((i2 >> 4) & 0x0F))]
                buffer[outIndex + 2] = e1[Int(((i2 & 0x0F) << 2) | ((i3 >> 6) & 0x03))]
                buffer[outIndex + 3] = e1[Int(i3)]
                outIndex += 4
            }

            if to < input.count {
                let index = to

                let i1 = input[index]
                let i2 = index + 1 < input.count ? input[index + 1] : nil
                let i3 = index + 2 < input.count ? input[index + 2] : nil

                buffer[outIndex] = e0[Int(i1)]

                if let i2 = i2, let i3 = i3 {
                    buffer[outIndex + 1] = e1[Int(((i1 & 0x03) << 4) | ((i2 >> 4) & 0x0F))]
                    buffer[outIndex + 2] = e1[Int(((i2 & 0x0F) << 2) | ((i3 >> 6) & 0x03))]
                    buffer[outIndex + 3] = e1[Int(i3)]
                    outIndex += 4
                } else if let i2 = i2 {
                    buffer[outIndex + 1] = e1[Int(((i1 & 0x03) << 4) | ((i2 >> 4) & 0x0F))]
                    buffer[outIndex + 2] = e1[Int((i2 & 0x0F) << 2)]
                    outIndex += 3
                    if !omitPaddingCharacter {
                        buffer[outIndex] = Self.encodePaddingCharacter
                        outIndex += 1
                    }
                } else {
                    buffer[outIndex + 1] = e1[Int((i1 & 0x03) << 4)]
                    outIndex += 2
                    if !omitPaddingCharacter {
                        buffer[outIndex] = Self.encodePaddingCharacter
                        buffer[outIndex + 1] = Self.encodePaddingCharacter
                        outIndex += 2
                    }
                }
            }

            length = outIndex
        }
    }

    @inlinable
    static func withUnsafeEncodingTablesAsBufferPointers<R>(
        options: Base64.EncodingOptions,
        _ body: (UnsafeBufferPointer<UInt8>, UnsafeBufferPointer<UInt8>) throws -> R
    ) rethrows -> R {
        let encoding0 = options.contains(.base64UrlAlphabet) ? Self.encoding0url : Self.encoding0
        let encoding1 = options.contains(.base64UrlAlphabet) ? Self.encoding1url : Self.encoding1

        assert(encoding0.count == 256)
        assert(encoding1.count == 256)

        return try encoding0.withUnsafeBufferPointer { e0 -> R in
            try encoding1.withUnsafeBufferPointer { e1 -> R in
                try body(e0, e1)
            }
        }
    }
}

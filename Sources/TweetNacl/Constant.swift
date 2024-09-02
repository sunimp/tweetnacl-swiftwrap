//
//  Constant.swift
//
//  Created by Sun on 2017/10/20.
//

enum Constants {
    enum Box {
        static let publicKeyBytes = 32
        static let secretKeyBytes = 32
        static let beforeNMBytes = 32
        static let nonceBytes = Secretbox.nonceBytes
        static let zeroBytes = Secretbox.zeroBytes
        static let boxZeroBytes = Secretbox.boxZeroBytes
    }

    enum Hash {
        static let bytes = 64
    }

    enum Scalarmult {
        static let bytes = 32
        static let scalarBytes = 32
    }

    enum Secretbox {
        static let keyBytes = 32
        static let nonceBytes = 24
        static let zeroBytes = 32
        static let boxZeroBytes = 16
    }

    enum Sign {
        static let bytes = 64
        static let publicKeyBytes = 32
        static let secretKeyBytes = 64
        static let seedBytes = 32
    }
}

//
//  TweetNacl.swift
//
//  Created by Sun on 2016/12/13.
//

import CTweetNacl
import Foundation

// MARK: - NaclUtil

public enum NaclUtil {
    // MARK: Nested Types

    public enum NaclUtilError: Error {
        case badKeySize
        case badNonceSize
        case badPublicKeySize
        case badSecretKeySize
        case internalError
    }

    // MARK: Static Functions

    public static func secureRandomData(count: Int) throws -> Data {
        // Generation method is platform dependent
        // (The Security framework is only available on Apple platforms).
        #if os(Linux)

        var bytes = [UInt8]()
        for _ in 0 ..< count {
            let randomByte = UInt8.random(in: UInt8.min ... UInt8.max)
            bytes.append(randomByte)
        }
        return Data(bytes: &bytes, count: count)

        #else

        var randomData = Data(count: count)
        let result = randomData.withUnsafeMutableBytes { (rawBufferPointer: UnsafeMutableRawBufferPointer) -> Int32 in
            guard let baseAddress = rawBufferPointer.baseAddress else {
                return errSecParam
            }
            return SecRandomCopyBytes(kSecRandomDefault, count, baseAddress)
        }
        guard result == errSecSuccess else {
            throw NaclUtilError.internalError
        }

        return randomData

        #endif
    }
    
    public static func hash(message: Data) throws -> Data {
        var hash = Data(count: Constants.Hash.bytes)
        let r = hash.withUnsafeMutableBytes { (hashBufferPointer: UnsafeMutableRawBufferPointer) -> Int32 in
            guard let hashPointer = hashBufferPointer.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                return -1
            }
            return message.withUnsafeBytes { (messageBufferPointer: UnsafeRawBufferPointer) -> Int32 in
                guard let messagePointer = messageBufferPointer.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                    return -1
                }
                return CTweetNacl.crypto_hash_sha512_tweet(hashPointer, messagePointer, UInt64(message.count))
            }
        }
        if r != 0 {
            throw NaclUtilError.internalError
        }
        
        return hash
    }
    
    public static func verify(x: Data, y: Data) throws -> Bool {
        if x.isEmpty || y.isEmpty {
            throw NaclUtilError.badKeySize
        }
        
        if x.count != y.count {
            throw NaclUtilError.badKeySize
        }
        
        let r = x.withUnsafeBytes { (xBufferPointer: UnsafeRawBufferPointer) -> Int32 in
            guard let xPointer = xBufferPointer.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                return -1
            }
            return y.withUnsafeBytes { (yBufferPointer: UnsafeRawBufferPointer) -> Int32 in
                guard let yPointer = yBufferPointer.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                    return -1
                }
                return CTweetNacl.crypto_verify_32_tweet(xPointer, yPointer)
            }
        }
        return r == 0
    }

    static func checkLengths(key: Data, nonce: Data) throws {
        if key.count != Constants.Secretbox.keyBytes {
            throw NaclUtilError.badKeySize
        }
        
        if nonce.count != Constants.Secretbox.nonceBytes {
            throw NaclUtilError.badNonceSize
        }
    }
    
    static func checkBoxLength(publicKey: Data, secretKey: Data) throws {
        if publicKey.count != Constants.Box.publicKeyBytes {
            throw NaclUtilError.badPublicKeySize
        }
        
        if secretKey.count != Constants.Box.secretKeyBytes {
            throw NaclUtilError.badSecretKeySize
        }
    }
}

// MARK: - NaclWrapper

enum NaclWrapper {
    // MARK: Nested Types

    enum NaclWrapperError: Error {
        case invalidParameters
        case internalError
        case creationFailed
    }

    // MARK: Static Functions

    static func crypto_box_keypair(secretKey sk: Data) throws -> (publicKey: Data, secretKey: Data) {
        var pk = Data(count: Constants.Box.secretKeyBytes)
        
        let result = pk.withUnsafeMutableBytes { pkBufferPointer in
            guard let pkPointer = pkBufferPointer.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                return -1
            }
            return sk.withUnsafeBytes { skBufferPointer in
                guard let skPointer = skBufferPointer.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                    return -1
                }
                return Int(CTweetNacl.crypto_scalarmult_curve25519_tweet_base(pkPointer, skPointer))
            }
        }
        if result != 0 {
            throw NaclWrapperError.internalError
        }
        
        return (pk, sk)
    }
    
    static func crypto_sign_keypair() throws -> (publicKey: Data, secretKey: Data) {
        let sk = try NaclUtil.secureRandomData(count: Constants.Sign.secretKeyBytes)
        
        return try crypto_sign_keypair_seeded(secretKey: sk)
    }
    
    static func crypto_sign_keypair_seeded(secretKey: Data) throws -> (publicKey: Data, secretKey: Data) {
        var pk = Data(count: Constants.Sign.publicKeyBytes)
        var sk = Data(count: Constants.Sign.secretKeyBytes)
        sk.replaceSubrange(
            0 ..< Constants.Sign.publicKeyBytes,
            with: secretKey.subdata(in: 0 ..< Constants.Sign.publicKeyBytes)
        )
        
        let result = pk.withUnsafeMutableBytes { pkBufferPointer in
            guard let pkPointer = pkBufferPointer.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                return -1
            }
            return sk.withUnsafeMutableBytes { skBufferPointer in
                guard let skPointer = skBufferPointer.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                    return -1
                }
                return Int(CTweetNacl.crypto_sign_ed25519_tweet_keypair(pkPointer, skPointer))
            }
        }
        if result != 0 {
            throw NaclWrapperError.internalError
        }
        
        return (pk, sk)
    }
}

// MARK: - NaclSecretBox

public enum NaclSecretBox {
    // MARK: Nested Types

    public enum NaclSecretBoxError: Error {
        case invalidParameters
        case internalError
        case creationFailed
    }

    // MARK: Static Functions

    public static func secretBox(message: Data, nonce: Data, key: Data) throws -> Data {
        try NaclUtil.checkLengths(key: key, nonce: nonce)
        
        var m = Data(count: Constants.Secretbox.zeroBytes + message.count)
        m.replaceSubrange(Constants.Secretbox.zeroBytes ..< m.count, with: message)
        
        var c = Data(count: m.count)
        
        let result = c.withUnsafeMutableBytes { cBufferPointer in
            guard let cPointer = cBufferPointer.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                return -1
            }
            return m.withUnsafeBytes { mBufferPointer in
                guard let mPointer = mBufferPointer.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                    return -1
                }
                return nonce.withUnsafeBytes { nonceBufferPointer in
                    guard let noncePointer = nonceBufferPointer.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                        return -1
                    }
                    return key.withUnsafeBytes { keyBufferPointer in
                        guard let keyPointer = keyBufferPointer.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                            return -1
                        }
                        return Int(CTweetNacl.crypto_secretbox_xsalsa20poly1305_tweet(
                            cPointer,
                            mPointer,
                            UInt64(m.count),
                            noncePointer,
                            keyPointer
                        ))
                    }
                }
            }
        }
        if result != 0 {
            throw NaclSecretBoxError.internalError
        }
        return c.subdata(in: Constants.Secretbox.boxZeroBytes ..< c.count)
    }
    
    public static func open(box: Data, nonce: Data, key: Data) throws -> Data {
        try NaclUtil.checkLengths(key: key, nonce: nonce)
        
        // Fill data
        var c = Data(count: Constants.Secretbox.boxZeroBytes + box.count)
        c.replaceSubrange(Constants.Secretbox.boxZeroBytes ..< c.count, with: box)
        
        var m = Data(count: c.count)
        
        let result = m.withUnsafeMutableBytes { mBufferPointer in
            guard let mPointer = mBufferPointer.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                return -1
            }
            return c.withUnsafeBytes { cBufferPointer in
                guard let cPointer = cBufferPointer.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                    return -1
                }
                return nonce.withUnsafeBytes { nonceBufferPointer in
                    guard let noncePointer = nonceBufferPointer.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                        return -1
                    }
                    return key.withUnsafeBytes { keyBufferPointer in
                        guard let keyPointer = keyBufferPointer.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                            return -1
                        }
                        return Int(CTweetNacl.crypto_secretbox_xsalsa20poly1305_tweet_open(
                            mPointer,
                            cPointer,
                            UInt64(c.count),
                            noncePointer,
                            keyPointer
                        ))
                    }
                }
            }
        }
        if result != 0 {
            throw NaclSecretBoxError.creationFailed
        }
        
        return m.subdata(in: Constants.Secretbox.zeroBytes ..< c.count)
    }
}

// MARK: - NaclScalarMult

public enum NaclScalarMult {
    // MARK: Nested Types

    public enum NaclScalarMultError: Error {
        case invalidParameters
        case internalError
        case creationFailed
    }

    // MARK: Static Functions

    public static func scalarMult(n: Data, p: Data) throws -> Data {
        if n.count != Constants.Scalarmult.scalarBytes {
            throw NaclScalarMultError.invalidParameters
        }
        
        if p.count != Constants.Scalarmult.bytes {
            throw NaclScalarMultError.invalidParameters
        }
        
        var q = Data(count: Constants.Scalarmult.bytes)
        let result = q.withUnsafeMutableBytes { qBufferPointer in
            guard let qPointer = qBufferPointer.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                return -1
            }
            return n.withUnsafeBytes { nBufferPointer in
                guard let nPointer = nBufferPointer.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                    return -1
                }
                return p.withUnsafeBytes { pBufferPointer in
                    guard let pPointer = pBufferPointer.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                        return -1
                    }
                    return Int(CTweetNacl.crypto_scalarmult_curve25519_tweet(
                        qPointer,
                        nPointer,
                        pPointer
                    ))
                }
            }
        }
        if result != 0 {
            throw NaclScalarMultError.creationFailed
        }
        
        return q
    }
    
    public static func base(n: Data) throws -> Data {
        if n.count != Constants.Scalarmult.scalarBytes {
            throw NaclScalarMultError.invalidParameters
        }
        
        var q = Data(count: Constants.Scalarmult.bytes)
        
        let result = q.withUnsafeMutableBytes { qBufferPointer in
            guard let qPointer = qBufferPointer.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                return -1
            }
            return n.withUnsafeBytes { nBufferPointer in
                guard let nPointer = nBufferPointer.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                    return -1
                }
                return Int(CTweetNacl.crypto_scalarmult_curve25519_tweet_base(qPointer, nPointer))
            }
        }
        if result != 0 {
            throw NaclScalarMultError.creationFailed
        }
        
        return q
    }
}

// MARK: - NaclBox

public enum NaclBox {
    // MARK: Nested Types

    public enum NaclBoxError: Error {
        case invalidParameters
        case internalError
        case creationFailed
    }

    // MARK: Static Functions

    public static func box(message: Data, nonce: Data, publicKey: Data, secretKey: Data) throws -> Data {
        let key = try before(publicKey: publicKey, secretKey: secretKey)
        return try NaclSecretBox.secretBox(message: message, nonce: nonce, key: key)
    }
    
    public static func before(publicKey: Data, secretKey: Data) throws -> Data {
        try NaclUtil.checkBoxLength(publicKey: publicKey, secretKey: secretKey)
        
        var k = Data(count: Constants.Box.beforeNMBytes)
        
        let result = k.withUnsafeMutableBytes { kBufferPointer in
            guard let kPointer = kBufferPointer.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                return -1
            }
            return publicKey.withUnsafeBytes { pkBufferPointer in
                guard let pkPointer = pkBufferPointer.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                    return -1
                }
                return secretKey.withUnsafeBytes { skBufferPointer in
                    guard let skPointer = skBufferPointer.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                        return -1
                    }
                    return Int(CTweetNacl.crypto_box_curve25519xsalsa20poly1305_tweet_beforenm(
                        kPointer,
                        pkPointer,
                        skPointer
                    ))
                }
            }
        }
        if result != 0 {
            throw NaclBoxError.creationFailed
        }
        
        return k
    }
    
    public static func open(message: Data, nonce: Data, publicKey: Data, secretKey: Data) throws -> Data {
        let k = try before(publicKey: publicKey, secretKey: secretKey)
        return try NaclSecretBox.open(box: message, nonce: nonce, key: k)
    }
    
    public static func keyPair() throws -> (publicKey: Data, secretKey: Data) {
        let sk = try NaclUtil.secureRandomData(count: Constants.Box.secretKeyBytes)
        
        return try NaclWrapper.crypto_box_keypair(secretKey: sk)
    }
    
    public static func keyPair(fromSecretKey sk: Data) throws -> (publicKey: Data, secretKey: Data) {
        if sk.count != Constants.Box.secretKeyBytes {
            throw NaclBoxError.invalidParameters
        }
        
        return try NaclWrapper.crypto_box_keypair(secretKey: sk)
    }
}

// MARK: - NaclSign

public enum NaclSign {
    // MARK: Nested Types

    public enum NaclSignError: Error {
        case invalidParameters
        case internalError
        case creationFailed
    }
    
    public enum KeyPair {
        public static func keyPair() throws -> (publicKey: Data, secretKey: Data) {
            return try NaclWrapper.crypto_sign_keypair()
        }
        
        public static func keyPair(fromSecretKey secretKey: Data) throws -> (publicKey: Data, secretKey: Data) {
            if secretKey.count != Constants.Sign.secretKeyBytes {
                throw NaclSignError.invalidParameters
            }
            
            let pk = secretKey.subdata(in: Constants.Sign.publicKeyBytes ..< Constants.Sign.secretKeyBytes)
            
            return (pk, secretKey)
        }
        
        public static func keyPair(fromSeed seed: Data) throws -> (publicKey: Data, secretKey: Data) {
            if seed.count != Constants.Sign.seedBytes {
                throw NaclSignError.invalidParameters
            }
            
            return try NaclWrapper.crypto_sign_keypair_seeded(secretKey: seed)
        }
    }

    // MARK: Static Functions

    public static func sign(message: Data, secretKey: Data) throws -> Data {
        if secretKey.count != Constants.Sign.secretKeyBytes {
            throw NaclSignError.invalidParameters
        }
        
        var signedMessage = Data(count: Constants.Sign.bytes + message.count)
        
        let tmpLength = UnsafeMutablePointer<UInt64>.allocate(capacity: 1)
        
        let result = signedMessage.withUnsafeMutableBytes { signedMessageBufferPointer in
            guard
                let signedMessagePointer = signedMessageBufferPointer.baseAddress?
                    .assumingMemoryBound(to: UInt8.self)
            else {
                return -1
            }
            return message.withUnsafeBytes { messageBufferPointer in
                guard let messagePointer = messageBufferPointer.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                    return -1
                }
                return secretKey.withUnsafeBytes { secretKeyBufferPointer in
                    guard
                        let secretKeyPointer = secretKeyBufferPointer.baseAddress?
                            .assumingMemoryBound(to: UInt8.self)
                    else {
                        return -1
                    }
                    return Int(CTweetNacl.crypto_sign_ed25519_tweet(
                        signedMessagePointer,
                        tmpLength,
                        messagePointer,
                        UInt64(message.count),
                        secretKeyPointer
                    ))
                }
            }
        }
        if result != 0 {
            throw NaclSignError.internalError
        }
        
        return signedMessage
    }
    
    public static func signOpen(signedMessage: Data, publicKey: Data) throws -> Data {
        if publicKey.count != Constants.Sign.publicKeyBytes {
            throw NaclSignError.invalidParameters
        }
        
        var tmp = Data(count: signedMessage.count)
        let tmpLength = UnsafeMutablePointer<UInt64>.allocate(capacity: 1)
        
        let result = tmp.withUnsafeMutableBytes { tmpBufferPointer in
            guard let tmpPointer = tmpBufferPointer.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                return -1
            }
            return signedMessage.withUnsafeBytes { signedMessageBufferPointer in
                guard
                    let signMessagePointer = signedMessageBufferPointer.baseAddress?
                        .assumingMemoryBound(to: UInt8.self)
                else {
                    return -1
                }
                return publicKey.withUnsafeBytes { publicKeyBufferPointer in
                    guard
                        let publicKeyPointer = publicKeyBufferPointer.baseAddress?
                            .assumingMemoryBound(to: UInt8.self)
                    else {
                        return -1
                    }
                    return Int(CTweetNacl.crypto_sign_ed25519_tweet_open(
                        tmpPointer,
                        tmpLength,
                        signMessagePointer,
                        UInt64(signedMessage.count),
                        publicKeyPointer
                    ))
                }
            }
        }
        if result != 0 {
            throw NaclSignError.creationFailed
        }
        
        return tmp
    }
    
    public static func signDetached(message: Data, secretKey: Data) throws -> Data {
        let signedMessage = try sign(message: message, secretKey: secretKey)
        
        let sig = signedMessage.subdata(in: 0 ..< Constants.Sign.bytes)
        
        return sig as Data
    }
    
    public static func signDetachedVerify(message: Data, sig: Data, publicKey: Data) throws -> Bool {
        if sig.count != Constants.Sign.bytes {
            throw NaclSignError.invalidParameters
        }
        
        if publicKey.count != Constants.Sign.publicKeyBytes {
            throw NaclSignError.invalidParameters
        }
        
        var sm = Data()
        
        var m = Data(count: Constants.Sign.bytes + message.count)
        
        sm.append(sig)
        sm.append(message)
        
        let tmpLength = UnsafeMutablePointer<UInt64>.allocate(capacity: 1)
        
        let result = m.withUnsafeMutableBytes { mBufferPointer in
            guard let mPointer = mBufferPointer.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                return -1
            }
            return sm.withUnsafeBytes { smBufferPointer in
                guard let smPointer = smBufferPointer.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                    return -1
                }
                return publicKey.withUnsafeBytes { publicKeyBufferPointer in
                    guard
                        let publicKeyPointer = publicKeyBufferPointer.baseAddress?
                            .assumingMemoryBound(to: UInt8.self)
                    else {
                        return -1
                    }
                    return Int(CTweetNacl.crypto_sign_ed25519_tweet_open(
                        mPointer,
                        tmpLength,
                        smPointer,
                        UInt64(sm.count),
                        publicKeyPointer
                    ))
                }
            }
        }
        return result == 0
    }
}

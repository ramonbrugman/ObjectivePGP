//
//  PGPPublicKeyPacket.m
//  ObjectivePGP
//
//  Created by Marcin Krzyzanowski on 18/01/15.
//  Copyright (c) 2015 Marcin Krzyżanowski. All rights reserved.
//
//  5.5.1.1.  Public-Key Packet (Tag 6)
//  A Public-Key packet starts a series of packets that forms an OpenPGP
//  key (sometimes called an OpenPGP certificate).


#import "PGPPublicKeyPacket.h"
#import "PGPCommon.h"
#import "NSInputStream+PGP.h"
#import "NSOutputStream+PGP.h"
#import "PGPMPI.h"

@implementation PGPPublicKeyPacket

+ (instancetype) readFromStream:(NSInputStream *)inputStream maxLength:(NSUInteger)maxLength error:(NSError * __autoreleasing *)error
{
//    // read packet body at once
//    Byte bytes[maxLength];
//    if ([stream read:bytes maxLength:maxLength] == -1) {
//        if (error) {
//            *error = [NSError errorWithDomain:PGPErrorDomain code:0 userInfo:@{NSLocalizedDescriptionKey: @"Can't read from stream"}];
//        }
//        return nil;
//    }
//    
//    NSInputStream *inputStream = [NSInputStream inputStreamWithData:[NSData dataWithBytes:bytes length:sizeof(bytes)]];
    PGPPublicKeyPacket *packet = [[PGPPublicKeyPacket alloc] init];
    
    // A one-octet version number
    UInt8 version = [inputStream readUInt8];
    packet.version = version;
    NSAssert(version >= 0x03 && version <= 0x04, @"Version not supported");
    if (version < 0x03 && version > 0x04) {
        if (error) {
            *error = [NSError errorWithDomain:PGPErrorDomain code:0 userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Version %@ not supported", @(version)]}];
        }
        return nil;
    }
    
    // A four-octet number denoting the time that the key was created.
    UInt32 timestamp = [inputStream readUInt32];
    if (timestamp) {
        packet.createDate = [NSDate dateWithTimeIntervalSince1970:timestamp];
    }
    
    if (version == 0x03) {
        // A two-octet number denoting the time in days that this key is
        // valid.  If this number is zero, then it does not expire.
        UInt16 validityPeriod = [inputStream readUInt16];
        packet.validityPeriod = validityPeriod;
    }
    
    // A one-octet number denoting the public-key algorithm of this key.
    packet.keyAlgorithm = [inputStream readUInt8];
    
    // A series of multiprecision integers comprising the key material.
    NSMutableSet *mpis = [NSMutableSet set];
    switch (packet.keyAlgorithm) {
        case PGPPublicKeyAlgorithmRSA:
        case PGPPublicKeyAlgorithmRSAEncryptOnly:
        case PGPPublicKeyAlgorithmRSASignOnly:
        {
            // MPI of RSA public modulus n;
            PGPMPI *mpiN = [PGPMPI readFromStream:inputStream error:error];
            mpiN.identifier = @"N";
            [mpis addObject:mpiN];
            // MPI of RSA public encryption exponent e.
            PGPMPI *mpiE = [PGPMPI readFromStream:inputStream error:error];
            mpiE.identifier = @"E";
            [mpis addObject:mpiE];
        }
            break;
        case PGPPublicKeyAlgorithmDSA:
        case PGPPublicKeyAlgorithmECDSA:
        {
            // MPI of DSA prime p;
            PGPMPI *mpiP = [PGPMPI readFromStream:inputStream error:error];
            mpiP.identifier = @"P";
            [mpis addObject:mpiP];
            
            //MPI of DSA group order q (q is a prime divisor of p-1);
            PGPMPI *mpiQ = [PGPMPI readFromStream:inputStream error:error];
            mpiQ.identifier = @"Q";
            [mpis addObject:mpiQ];
            
            //MPI of DSA group generator g;
            PGPMPI *mpiG = [PGPMPI readFromStream:inputStream error:error];
            mpiG.identifier = @"G";
            [mpis addObject:mpiG];
            
            //MPI of DSA public-key value y (= g**x mod p where x is secret).
            PGPMPI *mpiY = [PGPMPI readFromStream:inputStream error:error];
            mpiY.identifier = @"Y";
            [mpis addObject:mpiY];
        }
            break;
        case PGPPublicKeyAlgorithmElgamal:
        case PGPPublicKeyAlgorithmElgamalEncryptorSign:
            {
                //MPI of Elgamal prime p;
                PGPMPI *mpiP = [PGPMPI readFromStream:inputStream error:error];
                mpiP.identifier = @"P";
                [mpis addObject:mpiP];
                
                //MPI of Elgamal group generator g;
                PGPMPI *mpiG = [PGPMPI readFromStream:inputStream error:error];
                mpiG.identifier = @"G";
                [mpis addObject:mpiG];
                
                //MPI of Elgamal public key value y (= g**x mod p where x is secret).
                PGPMPI *mpiY = [PGPMPI readFromStream:inputStream error:error];
                mpiY.identifier = @"Y";
                [mpis addObject:mpiY];
            }
            break;
        default:
            if (error) {
                *error = [NSError errorWithDomain:PGPErrorDomain code:0 userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Public key algorithm %@ is not supported", @(packet.keyAlgorithm)]}];
            }
            return nil;
    }

    packet.MPIs = [mpis copy];
    return packet;
}

- (BOOL) writeToStream:(NSOutputStream *)outputStream error:(NSError * __autoreleasing *)error
{
    NSParameterAssert(outputStream);
    
    [outputStream writeUInt8:self.version];
    [outputStream writeUInt32:[self.createDate timeIntervalSince1970]];
    if (self.version == 0x03) {
        [outputStream writeUInt16:self.validityPeriod];
    }
    [outputStream writeUInt8:self.keyAlgorithm];
    for (PGPMPI *mpi in self.MPIs) {
        if (![mpi writeToStream:outputStream error:error]) {
            return NO;
        }
    }
    
    return YES;
}

@end

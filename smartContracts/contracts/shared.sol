// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

// Uncomment this line to use console.log
// import "hardhat/console.sol";

/**
 * proposals can be either binary or multiple options
 */
enum proposalType {
    binary,
    multiple
}
/**
 * stores the settings for an org
 *
 *
 */
struct OrgSettings {
    uint8 majority; // percentage of passed votes quorum = majority /100 (only applicable in yes or no proposals)
    uint8 qourum; // percentage of people to be present = qourum /100    0-100(the percentage that need to be reached to start tallying votes)
}

// the structure of a ballot object
struct Ballot {
    string proposal;
    string[] options;
    bool valid;
}

// the structure of a binaryballot object
struct BinaryBallot {
    string proposal;
    bool valid;
}

/**
 * result for each reached proposal
 * for binary proposals, decision is stored as bool
 * for non binary ones, decision is stored as string
 */
struct Result {
    string proposal;
    proposalType tp;
    bytes decision; // bool | string
}

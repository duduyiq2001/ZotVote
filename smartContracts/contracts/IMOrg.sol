// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

// Uncomment this line to use console.log
// import "hardhat/console.sol";
import "./shared.sol";

interface IMOrg {
    /**
     * terminating the org contract by rendering it unusable
     */
    function destroy() external;
}

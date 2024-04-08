// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

// Uncomment this line to use console.log
// import "hardhat/console.sol";

//Factories for all individual orgs

import "./Org.sol";
import "./shared.sol";

contract MasterOrg {
    address payable public owner;

    mapping(address => uint) public orgAddresses;
    // whenever a new organization is added, emit a message
    event OrgAdded(address owner, address contractaddr, string name);
    // require a user to be owner
    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    constructor() payable {
        owner = payable(msg.sender);
    }

    /**
     * Only the owner of the master contract can create a new org
     * @param orgName the name of the organization
     * @param settings the settings for the new org
     */

    function addOrg(
        string calldata orgName,
        OrgSettings calldata settings
    ) public onlyOwner {
        Org neworg = new Org(msg.sender, orgName, settings);
        address newOrgAddress = address(neworg); // return the address of the neworg
        orgAddresses[newOrgAddress] = 1; // store the address into an arrays
        emit OrgAdded(msg.sender, newOrgAddress, orgName);
    }

    /**
     * Only the owner of the master contract can delete an org
     * Only called after org self destruct
     * @param org the address to be deleted
     */
    function deleteOrg(address org) public onlyOwner {
        // destroy internal data structures of such org
        IMOrg targetOrg = IMOrg(org);
        targetOrg.destroy();
        // remove org
        orgAddresses[org] = 0;
    }
}

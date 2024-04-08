// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

// Uncomment this line to use console.log
// import "hardhat/console.sol";
import "./shared.sol";
import "./IMOrg.sol";

contract Org {
    // owner of the org
    address payable public owner;
    // master contract address
    address payable public coowner;
    // name of the org (modifiable through vote)
    string public orgName;
    // settings of org including quorum and majority
    OrgSettings public settings;
    // all members of the org
    address[] public members;
    mapping(address => uint) membersid;
    // highest user id
    uint uhighid;
    // all of existing proposals
    mapping(uint => Ballot) public ballotsid;
    uint[] public ballots;
    // all of binary proposals
    mapping(uint => BinaryBallot) public binaryBallotsid;
    uint[] public binaryBallots;
    // the highest ballot id
    uint highid;
    // all of passed proposals
    Result[] public results;
    // tally of each proposal (proposal index -> optionindex -> count)
    mapping(uint => mapping(uint => uint)) public tally;
    // count of total votes for each proposal
    mapping(uint => uint) private tallyCount;
    // tracking if user has voted
    mapping(uint => mapping(address => bool)) public hasVoted;
    // used to lock the org if it's intended to be terminated by the master contract
    bool masterLock;

    /**
     * Events
     */

    //triggered whenever a user cast a vote
    event voteCasted(address voter, uint proposalId);
    //triggered when a proposal is tied
    event proposalTied(uint proposalId, uint[] options);
    //triggered whenever a proposal is created
    event proposalCreated(address user, uint proposalId);
    //triggered whenever a proposal decision is reached
    event proposalReached(uint proposalId, uint option);
    //triggered whenever a proposal result is validated
    event proposalValidated(uint proposalId);
    //triggered when the org is terminated either by the owner or the master contract
    event orgTerminated(string orgName);

    constructor(
        address orgowner,
        string memory orgname,
        OrgSettings memory setting
    ) payable {
        // setting coowner of the master contract address
        coowner = payable(msg.sender);
        // setting owner and name
        owner = payable(orgowner);
        orgName = orgname;
        // configure settings
        settings = setting;
        // setting the highest id to 0
        highid = 0;
        // setting the highest userid to 1
        uhighid = 1;
        // adding owner as the first member
        addMember(owner);
        // unlock the org
        masterLock = false;
    }

    /**
     * internal functions
     */

    /**
     *
     * @param user checking if the user is a member
     */
    function isMember(address user) internal view returns (bool) {
        if (membersid[user] == 0) {
            return false;
        }
        return true;
    }

    /**
     * checking if proposal id is valid
     */

    function isValidProposal(
        uint id,
        proposalType tp
    ) internal view returns (bool) {
        if (
            (ballotsid[id].valid != false && tp == proposalType.multiple) ||
            (binaryBallotsid[id].valid != false && tp == proposalType.binary)
        ) {
            return true;
        }
        return false;
    }

    /**
     * checking if the option selected is valid
     * @param id the id of the proposal
     * @param tp the type of the proposal (binary or multiple)
     * @param option the index of the option
     */
    function isValidOption(
        uint id,
        proposalType tp,
        uint option
    ) internal view returns (bool) {
        // binary options can not be greater than one
        if (tp == proposalType.binary && option > 1) {
            return false;
        }
        // option number cannot be greater or equal to length for multiple
        if (
            tp == proposalType.multiple &&
            option >= ballotsid[id].options.length
        ) {
            return false;
        }
        return true;
    }

    /**
     * check if such user has voted
     * @param user address of voter
     * @param proposalId id of proposal
     */
    function userVoted(
        address user,
        uint proposalId
    ) internal view returns (bool) {
        return hasVoted[proposalId][user];
    }

    /**
     * checking if the quorum has been reached to trigger a count vote
     * @param proposalId the id of the proposal
     */
    function checkQuorum(uint proposalId) internal view returns (bool) {
        if (
            ((tallyCount[proposalId] * 100) / members.length) >= settings.qourum
        ) {
            return true;
        }
        return false;
    }

    function binarySearchR(
        uint[] storage array,
        uint value,
        uint lowindex,
        uint highindex
    ) internal view returns (uint) {
        if (lowindex > highindex) {
            return array.length; // Return an impossible index when not found
        }
        uint mid = (highindex - lowindex) / 2 + lowindex; // calculating middle index
        if (value == array[mid]) {
            return mid;
        } else {
            if (highindex == lowindex) {
                return array.length; // return an impossible index when not found
            }
            if (value < array[mid]) {
                return
                    mid > 0
                        ? binarySearchR(array, value, lowindex, mid - 1)
                        : array.length; // checking mid don't go under flow
            }
            return binarySearchR(array, value, mid + 1, highindex);
        }
    }

    /** logn time to search through arrays
     * @param array array to be searched
     * @param value value to be searched
     * @return index of found value
     * array.length when not found
     */
    function binarySearch(
        uint[] storage array,
        uint value
    ) internal view returns (uint) {
        return binarySearchR(array, value, 0, array.length - 1);
    }

    /**
     * removing a proposal from all ballot associated data structures
     * @param proposalId id of proposal
     */
    function removeProposal(uint proposalId) internal {
        // cleaning up all the storage it held
        ballotsid[proposalId].options = new string[](0);
        ballotsid[proposalId].valid = false; // setting the valid bit to 0
        ballotsid[proposalId].proposal = "";

        // removing it from array
        uint index = binarySearch(ballots, proposalId);
        // if proposal is found
        if (index < ballots.length) {
            ballots[index] = ballots[ballots.length - 1];
            ballots.pop();
        }
    }

    /**
     * removing a proposal from all ballot associated data structures
     * @param proposalId id of proposal
     */
    function removeBinaryProposal(uint proposalId) internal {
        // cleaning up all the storage it held
        binaryBallotsid[proposalId].valid = false; // setting the valid bit to 0
        binaryBallotsid[proposalId].proposal = "";

        // removing it from array
        uint index = binarySearch(binaryBallots, proposalId);
        // if proposal is found
        if (index < ballots.length) {
            binaryBallots[index] = binaryBallots[binaryBallots.length - 1];
            binaryBallots.pop();
        }
    }

    /**
     * modifiers
     */
    // require a user to be owner
    modifier onlyOwner() {
        require(msg.sender == owner || msg.sender == coowner);
        _;
    }
    // require user to be a member
    modifier onlyMember() {
        require(isMember(msg.sender) == true);
        _;
    }

    /**
     * terminating the org contract by rendering it unusable
     */
    function destroy() public {
        require(msg.sender == owner || msg.sender == coowner, "Not authorized");
        // change the owner to non existent address
        owner = payable(address(0));
        // delete members from list
        delete (members);
        // locking the org
        masterLock = true;
        // emit an event that notifies backend
        emit orgTerminated(orgName);
        // transfer funds if any
        // no funds right now
    }

    /**
     * public functions
     */

    /**
     * only owner of org can add to it
     * @param newmember new member to be added to the members list
     */
    function addMember(address newmember) public onlyOwner {
        // require that the user does not already exists
        require(isMember(newmember) == false);
        // add to array
        members.push(newmember);
        // set id of user
        membersid[newmember] = uhighid;
        // increment uhigh
        uhighid += 1;
    }

    /**
     * create multi option proposals specifying
     * @param proposalName name of the proposal
     * @param options a list of options
     */
    function createProposal(
        string memory proposalName,
        string[] memory options
    ) public onlyMember {
        // create new ballot
        Ballot memory newballot = Ballot({
            proposal: proposalName,
            options: options,
            valid: true
        });
        // adding new ballot
        ballots.push(highid);
        ballotsid[highid] = newballot;
        //increase high id
        highid += 1;
        // emit proposal event
        emit proposalCreated(msg.sender, highid - 1);
    }

    /**
     *
     * @param proposalName name of the proposal
     */
    function createBinaryProposal(
        string memory proposalName
    ) public onlyMember {
        // create new ballot
        BinaryBallot memory newballot = BinaryBallot({
            proposal: proposalName,
            valid: true
        });
        // adding new ballot
        binaryBallots.push(highid);
        binaryBallotsid[highid] = newballot;
        //increase high id
        highid += 1;
        // emit proposal event
        emit proposalCreated(msg.sender, highid - 1);
    }

    /**
     * vote on a proposal by id (can be binary)
     * @param proposalId id of proposal
     */
    function vote(
        uint proposalId,
        proposalType tp,
        uint optionIndex
    ) public onlyMember {
        /**
         * first we require that the proposal has to exist and has not been trashed
         * second we insure that such user do not double vote
         * thired we insure that the option that the user chose is valid
         */
        require(isValidProposal(proposalId, tp) == true);
        require(userVoted(msg.sender, proposalId) == false);
        require(isValidOption(proposalId, tp, optionIndex) == true);
        // increment tally
        tally[proposalId][optionIndex] += 1;
        // counting user as voted
        hasVoted[proposalId][msg.sender] = true;
        // increment total votes for each proposal
        tallyCount[proposalId] += 1;
        // emit event to signal casting of a vote
        emit voteCasted(msg.sender, proposalId);

        // check if quorum is reached
        if (checkQuorum(proposalId)) {
            /**
             * result checking
             */
            // for multi option proposals
            if (tp == proposalType.multiple) {
                // getting the length of the option
                uint optLength = ballotsid[proposalId].options.length;
                uint memLength = members.length;
                // keeping track of the highest vote count
                uint topVote = 0;
                uint[] memory topOpt = new uint[](optLength);
                // the array length of topOpt
                uint numOfTopOpts = 0;
                // iterate through all option tallies
                for (uint i = 0; i < optLength; i++) {
                    memLength -= tally[proposalId][i];
                    if (tally[proposalId][i] >= topVote) {
                        topVote = tally[proposalId][i];
                        // append the option numbers
                        topOpt[numOfTopOpts] = i;
                        // update array length
                        numOfTopOpts += 1;
                    }
                    // if the remaining possible votes is less than the current highest vote
                    // then we can apply early stopping
                    if (memLength < topVote) {
                        break;
                    }
                }
                /**
                 * termination of vote upon reached decision
                 */
                if (topOpt.length == 1) {
                    // store result into contract
                    Result memory voteResult = Result({
                        proposal: (ballotsid[proposalId].proposal),
                        tp: proposalType.multiple,
                        decision: bytes(
                            (ballotsid[proposalId].options[topOpt[0]])
                        )
                    });
                    results.push(voteResult);
                    // remove proposal
                    removeProposal(proposalId);
                    // emit event
                    emit proposalReached(proposalId, topOpt[0]);
                    return;
                }
                /**
                 *termination of vote and revote triggered upon full vote tie
                 */
                if (tallyCount[proposalId] == members.length) {
                    // inform a tied proposal
                    emit proposalTied(proposalId, topOpt);
                    Ballot memory revoteBallot = ballotsid[proposalId];
                    removeProposal(proposalId);
                    // adding new ballot
                    ballots.push(highid);
                    ballotsid[highid] = revoteBallot;
                    //increase high id
                    highid += 1;
                    // emit proposal event
                    emit proposalCreated(msg.sender, highid - 1);
                }
            }
            // for binary proposals
            else {
                // check majority
                if (
                    (tally[proposalId][0] * 100) / tallyCount[proposalId] >=
                    settings.majority
                ) {
                    // store result into contract
                    Result memory voteResult = Result({
                        proposal: (ballotsid[proposalId].proposal),
                        tp: proposalType.binary,
                        decision: bytes(abi.encodePacked(true))
                    });
                    results.push(voteResult);
                    // remove proposal
                    removeBinaryProposal(proposalId);
                    //emit event
                    emit proposalReached(proposalId, 0);
                    return;
                }
                // if full vote and majority still not reached
                if (tallyCount[proposalId] >= members.length) {
                    // here the proposal is rejected
                    // store result into contract
                    Result memory voteResult = Result({
                        proposal: (ballotsid[proposalId].proposal),
                        tp: proposalType.binary,
                        decision: bytes(abi.encodePacked(false))
                    });
                    results.push(voteResult);
                    // remove proposal
                    removeBinaryProposal(proposalId);
                    //emit event
                    emit proposalReached(proposalId, 1);
                    return;
                }
            }
        }
    }

    /**
     * public view functions
     */

    function getMember() public view returns (address[] memory) {
        return members;
    }

    function getBallots() public view returns (Ballot[] memory) {
        // create ballot array
        Ballot[] memory bArray = new Ballot[](ballots.length);
        for (uint i = 0; i < ballots.length; i++) {
            bArray[i] = ballotsid[ballots[i]];
        }
        return bArray;
    }

    function getBallotsId() public view returns (uint[] memory) {
        return ballots;
    }

    function getBinaryBallots() public view returns (BinaryBallot[] memory) {
        // create ballot array
        BinaryBallot[] memory bArray = new BinaryBallot[](binaryBallots.length);
        for (uint i = 0; i < binaryBallots.length; i++) {
            bArray[i] = binaryBallotsid[ballots[i]];
        }
        return bArray;
    }

    function getBinaryBallotsId() public view returns (uint[] memory) {
        return binaryBallots;
    }

    /**
     * @param proposalId id of proposal
     */
    function getTally(uint proposalId) public view returns (uint[] memory) {
        uint[] memory info = new uint[](ballotsid[proposalId].options.length);
        for (uint i = 0; i < ballotsid[proposalId].options.length; i++) {
            info[i] = tally[proposalId][i];
        }
        return info;
    }

    /**
     * @param proposalId id of proposal
     */
    function getBinaryTally(
        uint proposalId
    ) public view returns (uint[] memory) {
        uint[] memory info = new uint[](2);
        for (uint i = 0; i < 2; i++) {
            info[i] = tally[proposalId][i];
        }
        return info;
    }

    function getResults() public view returns (Result[] memory) {
        return results;
    }
}

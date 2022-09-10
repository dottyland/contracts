// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

// Import this file to use console.log
import "hardhat/console.sol";
// Chainlink imports
import '@chainlink/contracts/src/v0.8/ChainlinkClient.sol';
import '@chainlink/contracts/src/v0.8/ConfirmedOwner.sol';

contract Lock is ChainlinkClient, ConfirmedOwner{
    using Chainlink for Chainlink.Request;

    uint public unlockTime;
    address payable public owner;
    // Chainlink variables
    uint256 public score;
    bytes32 private jobId;
    uint256 private fee;

    event Withdrawal(uint amount, uint when);
    event RequestScore(bytes32 indexed requestId, uint256 score);

    constructor(uint _unlockTime) ConfirmedOwner(msg.sender) payable {
        require(
            block.timestamp < _unlockTime,
            "Unlock time should be in the future"
        );

        unlockTime = _unlockTime;
        owner = payable(msg.sender);

        setChainlinkToken(0x326C977E6efc84E512bB9C30f76E30c160eD06FB);
        // What target oracle will we be using?
        setChainlinkOracle();
        // Job ID here
        jobId = '';
        fee = (1 * LINK_DIVISIBILITY) / 10; // 0,1 * 10**18 (Varies by network and job)
    }

    function withdraw() public {
        // Uncomment this line to print a log in your terminal
        // console.log("Unlock time is %o and block timestamp is %o", unlockTime, block.timestamp);

        require(block.timestamp >= unlockTime, "You can't withdraw yet");
        require(msg.sender == owner, "You aren't the owner");

        emit Withdrawal(address(this).balance, block.timestamp);

        owner.transfer(address(this).balance);
    }

    /* 
        This function will request Chainlink Oracle data. The purpose of the function is to:
        * Create a Chainlink Request
        * Receive API Response
    */
    function requestImpactScore() public returns (bytes32 requestId){
        Chainlink.Request memory req = buildChainlinkRequest(jobId, address(this), this.receiveImpactScore.selector);

        // Setting URL to perform GET request
        req.add('get', 'https://impact-api.vercel.app/api/abc');

        // Setting the path for the JSON response
        req.add('path', 'body');

        // add any data cleaning here
        return sendChainlinkRequest(req, fee);
    }

    /* 
        This function will receive the Oracle data (uint256 score). The purpose of the function is to:
        * Receive calculated Impact Score
        * execute an action (mint an NFT)
    */
    function receiveImpactScore(bytes32 _requestId, uint256 _score) public recordChainlinkFulfillment(_requestId) {
        emit RequestScore(_requestId, _score);
        score = _score;
    } 

    function withdrawLink() public onlyOwner {
        LinkTokenInterface link = LinkTokenInterface(chainlinkTokenAddress());
        require(link.transfer(msg.sender, link.balanceOf(address(this))), 'Unable to transfer');
    }
}

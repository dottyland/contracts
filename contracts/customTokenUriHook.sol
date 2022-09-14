// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

// Import this file to use console.log
import "hardhat/console.sol";
import "@unlock-protocol/contracts/dist/Hooks/ILockTokenURIHook.sol";
// Chainlink imports
import "@chainlink/contracts/src/v0.8/ChainlinkClient.sol";
import "@chainlink/contracts/src/v0.8/ConfirmedOwner.sol";
import "@unlock-protocol/contracts/dist/PublicLock/IPublicLockV10.sol";

contract customTokenUriHook is
    ILockTokenURIHook,
    ChainlinkClient,
    ConfirmedOwner
{
    using Chainlink for Chainlink.Request;
   
    // Chainlink variables
    uint256 public score;
    bytes32 private jobId;
    uint256 private fee;
    address private LockAddress;
    mapping(uint256=>bool) public privacyList;
    mapping(uint256=>address[]) public accessList;
    mapping(uint256=>uint256) public scoreList;

    modifier tokenOwner(uint256 nftId) {
      IPublicLockV10 Lock= IPublicLockV10(LockAddress);
      require(msg.sender==Lock.ownerOf(nftId));
      _;
    }

    event RequestScore(bytes32 indexed requestId, uint256 score);

    function isPrivate(uint256 keyId) public view returns(bool){
      return privacyList[keyId];
    }
    constructor() payable ConfirmedOwner(msg.sender) {
        setChainlinkToken(0x326C977E6efc84E512bB9C30f76E30c160eD06FB);
        // Temporarily setting oracle to Polygon Mumbai
        setChainlinkOracle(0x40193c8518BB267228Fc409a613bDbD8eC5a97b3);
        // Job ID for uint256
        jobId = "ca98366cc7314957b8c012c72f05aeeb";
        fee = (1 * LINK_DIVISIBILITY) / 10; // 0,1 * 10**18 (Varies by network and job)
    }
    function tokenURI(
        address lockAddress,
        address operator,
        address owner,
        uint256 keyId,
        uint256 expirationTimestamp
    ) external view returns (string memory) {}

    /* 
        This function will request Chainlink Oracle data. The purpose of the function is to:
        * Create a Chainlink Request
        * Receive API Response
    */
    function requestImpactScore() public returns (bytes32 requestId) {
        Chainlink.Request memory req = buildChainlinkRequest(
            jobId,
            address(this),
            this.receiveImpactScore.selector
        );

        // Setting URL to perform GET request
        req.add("get", "https://impact-api.vercel.app/api/abc");

        // Setting the path for the JSON response
        req.add("path", "body");

        // add any data cleaning here
        return sendChainlinkRequest(req, fee);
    }

    /* 
      This function will receive the Oracle data (uint256 score). The purpose of the function is to:
      * Receive calculated Impact Score
      * execute an action (mint an NFT)
  */
    function receiveImpactScore(bytes32 _requestId, uint256 _score)
        public
        recordChainlinkFulfillment(_requestId)
    {
        emit RequestScore(_requestId, _score);
        score = _score;
    }

    function withdrawLink() public onlyOwner {
        LinkTokenInterface link = LinkTokenInterface(chainlinkTokenAddress());
        require(
            link.transfer(msg.sender, link.balanceOf(address(this))),
            "Unable to transfer"
        );
    }

    
    function giveAccess(uint256 tokenId,address[] calldata whitelist) public tokenOwner(tokenId) {
      for(uint i=0;i<whitelist.length;i++)
      accessList[tokenId].push(whitelist[i]);
    }
    function removeAccess(uint256 tokenId,address profile) public tokenOwner(tokenId){
      uint256 length=accessList[tokenId].length;
      for(uint i=0; i<length;i++)
      {
      if(accessList[tokenId][i]==profile)
      {
        accessList[tokenId][i]=accessList[tokenId][length-1];
        accessList[tokenId].pop();
      }
      }
    }
    function setPrivacy(uint256 tokenId,bool value) public tokenOwner(tokenId){
      if(value==true){
        setScore(tokenId,0);
      }
      else{
        //updatescore();
      }
    }
    function setScore(uint256 tokenId,uint256 newScore) internal tokenOwner(tokenId) {
      scoreList[tokenId]=newScore;
    }
}

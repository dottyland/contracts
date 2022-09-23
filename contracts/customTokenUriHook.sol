//Author Dottyv0.2
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

// Import this file to use console.log
import "hardhat/console.sol";
import "@unlock-protocol/contracts/dist/Hooks/ILockTokenURIHook.sol";
import "@unlock-protocol/contracts/dist/Hooks/ILockKeyPurchaseHook.sol";
// Chainlink imports
import "@chainlink/contracts/src/v0.8/ChainlinkClient.sol";
import "@chainlink/contracts/src/v0.8/ConfirmedOwner.sol";
import "@unlock-protocol/contracts/dist/PublicLock/IPublicLockV10.sol";
import "@openzeppelin/contracts/utils/Base64.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract customTokenUriHook is
    ILockTokenURIHook,
    ChainlinkClient,
    ConfirmedOwner,
    ILockKeyPurchaseHook
{
    using Chainlink for Chainlink.Request;
   
    // Chainlink variables
    bytes32 private jobId;
    uint256 private fee;
    address private LockAddress;
    string public url;
    bytes32 public request_Id;
    address public target;
    mapping(address => bool) public privacyList;
    mapping(address => address[]) public accessList;
    mapping(address => uint256) public scoreList;
    mapping(bytes32 => address) public tracker;

    modifier tokenOwner() {
        IPublicLockV10 Lock = IPublicLockV10(LockAddress);
        require(Lock.isOwner(msg.sender)==true);
        _;
    }

    event RequestScore(bytes32 indexed requestId, uint256 score);

    function geturl() public view returns(string memory) {
        return url;
    }
    function isPrivate(address owner) public view returns (bool) {
        return privacyList[owner];
    }

    constructor() payable ConfirmedOwner(msg.sender) {
        setChainlinkToken(0x326C977E6efc84E512bB9C30f76E30c160eD06FB);
        // Temporarily setting oracle to Polygon Mumbai
        setChainlinkOracle(0xCC79157eb46F5624204f47AB42b3906cAA40eaB7);
        // Job ID for uint256; adding multiple parameters
        jobId = "ca98366cc7314957b8c012c72f05aeeb";
        fee = (1 * LINK_DIVISIBILITY) / 10; // 0,1 * 10**18 (Varies by network and job)
    }
    function setLockAddress(address lockAddress) public onlyOwner {
        LockAddress=lockAddress;
    }

    function tokenURI(
        address lockAddress,
        address operator,
        address owner,
        uint256 keyId,
        uint256 expirationTimestamp
    ) external view returns (string memory) {
        if(privacyList[owner]==true)
        {
            bytes memory json = 
                    abi.encodePacked(
                        '{',
                        '"name": "Impact NFT",',
                        ' "description": "Impact",',
                        ' "image_data": "Hello",',
                        '"attributes" :',
                        '[{',
                        ' "score": "Private"',
                        '}]',
                        '}'                 
        );
                return string(
                    abi.encodePacked(
                        "data:application/json;base64,",
                        Base64.encode(json)
                    )
                );
        }else {
            string memory score=Strings.toString(scoreList[owner]);
             bytes memory json = 
                    abi.encodePacked(
                        '{',
                        '"name": "Impact NFT",',
                        ' "description": "Impact",',
                        ' "image_data": "Hello",',
                        '"attributes" :',
                        '[{',
                        '"public:"ye",',
                         ' "score": "',score,'"',
                        '}]',
                        '}'                 
        );
                return string(
                    abi.encodePacked(
                        "data:application/json;base64,",
                        Base64.encode(json)
                    )
                );
        }
        }

    /* 
        This function will request Chainlink Oracle data. The purpose of the function is to:
        * Create a Chainlink Request
        * Receive API Response
    */
    function requestImpactScore(address owner) internal returns (bytes32 requestId) {
        
        Chainlink.Request memory req = buildChainlinkRequest(
            jobId,
            address(this),
            this.receiveImpactScore.selector
        );
        string memory ownerstring= Strings.toHexString(uint256(uint160(owner)), 20);
        // Setting URL to perform GET request for score
        url=string(abi.encodePacked("https://impact-api.vercel.app/api/abc/",ownerstring));
        req.add("get", url);

        // Setting the path for the score JSON response
        req.add("path", "score");
        int256 multiplier=1;
        req.addInt("times",multiplier);

        // Setting the path for the tokenID JSON response

        // add any data cleaning here
        return sendChainlinkRequest(req, fee);
    }

    /* 
      This function will receive the Oracle data (uint256 score). The purpose of the function is to:
      * Receive calculated Impact Score
      * execute an action (mint an NFT)
  */
    function receiveImpactScore(
        bytes32 _requestId,
        uint256 _score
    ) public recordChainlinkFulfillment(_requestId) {
        emit RequestScore(_requestId, _score);
        address _target = tracker[_requestId];
        target = _target;
       scoreList[target]=_score;
       delete(tracker[_requestId]);
    }

    function withdrawLink() public onlyOwner {
        LinkTokenInterface link = LinkTokenInterface(chainlinkTokenAddress());
        require(
            link.transfer(msg.sender, link.balanceOf(address(this))),
            "Unable to transfer"
        );
    }
    function getIt(address owner) public view returns(uint256 score){
        return scoreList[owner];
    }

    function giveAccess( address[] calldata whitelist)
        public
        tokenOwner
    {
        for (uint256 i = 0; i < whitelist.length; i++)
            accessList[msg.sender].push(whitelist[i]);
    }

    function removeAccess(uint256 _tokenId, address profile)
        public
        tokenOwner
    {
        uint256 length = accessList[msg.sender].length;
        for (uint256 i = 0; i < length; i++) {
            if (accessList[msg.sender][i] == profile) {
                accessList[msg.sender][i] = accessList[msg.sender][length - 1];
                accessList[msg.sender].pop();
            }
        }
    }

    function setPrivacy(uint256 _tokenId, bool value)
        public
        tokenOwner
    {
        privacyList[msg.sender]==value;
        if (value == true) {
            scoreList[msg.sender]=0;
        } else {
            requestImpactScore(msg.sender);
        }
    }
    function keyPurchasePrice(
        address from,
    address recipient,
    address referrer,
    bytes calldata data
  ) external view
    returns (uint minKeyPrice){
        return 0;
    }
    function onKeyPurchase(address from,
    address recipient,
    address referrer,
    bytes calldata data,
    uint minKeyPrice,
    uint pricePaid
  ) external {
    bytes32 id=requestImpactScore(recipient);
    tracker[id]=recipient;
    request_Id=id;
  }
}

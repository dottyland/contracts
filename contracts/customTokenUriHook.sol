// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

// Import this file to use console.log
import "hardhat/console.sol";
import "@unlock-protocol/contracts/dist/Hooks/ILockTokenURIHook.sol";
// Chainlink imports
import "@chainlink/contracts/src/v0.8/ChainlinkClient.sol";
import "@chainlink/contracts/src/v0.8/ConfirmedOwner.sol";
import "@unlock-protocol/contracts/dist/PublicLock/IPublicLockV10.sol";
import "@openzeppelin/contracts/utils/Base64.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

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
    uint256 public tokenId;
    address nftContractAddress;
    mapping(uint256 => bool) public privacyList;
    mapping(uint256 => address[]) public accessList;
    mapping(uint256 => uint256) public scoreList;

    modifier tokenOwner(uint256 nftId) {
        IPublicLockV10 Lock = IPublicLockV10(LockAddress);
        require(msg.sender == Lock.ownerOf(nftId));
        _;
    }

    event RequestScore(bytes32 indexed requestId, uint256 score);

    function isPrivate(uint256 keyId) public view returns (bool) {
        return privacyList[keyId];
    }

    constructor() payable ConfirmedOwner(msg.sender) {
        setChainlinkToken(0x326C977E6efc84E512bB9C30f76E30c160eD06FB);
        // Temporarily setting oracle to Polygon Mumbai
        setChainlinkOracle(0x40193c8518BB267228Fc409a613bDbD8eC5a97b3);
        // Job ID for uint256; adding multiple parameters
        jobId = "53f9755920cd451a8fe46f5087468395";
        fee = (1 * LINK_DIVISIBILITY) / 10; // 0,1 * 10**18 (Varies by network and job)
    }

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

        // Setting URL to perform GET request for score
        req.add("getScore", "https://impact-api.vercel.app/api/abc");

        // Setting the path for the score JSON response
        req.add("pathScore", "x");

        // Setting URL to perform GET request for tokenID
        req.add("getTokenID", "x");

        // Setting the path for the tokenID JSON response
        req.add("pathTid", "x");

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
        uint256 _score,
        uint256 _tokenId
    ) public recordChainlinkFulfillment(_requestId) {
        emit RequestScore(_requestId, _score);
        score = _score;
        tokenId = _tokenId;
    }

    function withdrawLink() public onlyOwner {
        LinkTokenInterface link = LinkTokenInterface(chainlinkTokenAddress());
        require(
            link.transfer(msg.sender, link.balanceOf(address(this))),
            "Unable to transfer"
        );
    }

    function giveAccess(uint256 _tokenId, address[] calldata whitelist)
        public
        tokenOwner(_tokenId)
    {
        for (uint256 i = 0; i < whitelist.length; i++)
            accessList[_tokenId].push(whitelist[i]);
    }

    function removeAccess(uint256 _tokenId, address profile)
        public
        tokenOwner(_tokenId)
    {
        uint256 length = accessList[_tokenId].length;
        for (uint256 i = 0; i < length; i++) {
            if (accessList[_tokenId][i] == profile) {
                accessList[_tokenId][i] = accessList[_tokenId][length - 1];
                accessList[_tokenId].pop();
            }
        }
    }

    function setPrivacy(uint256 _tokenId, bool value)
        public
        tokenOwner(_tokenId)
    {
        if (value == true) {
            setScore(_tokenId, 0);
        } else {
            //updatescore();
        }
    }

    function setScore(uint256 _tokenId, uint256 newScore)
        internal
        tokenOwner(_tokenId)
    {
        scoreList[_tokenId] = newScore;
    }

    // the setNftContractAddress function sets our contract address to the impactNFT so that we can create the tokenURI. The contract address is to be passed here
    function setNftContractAddress(address _contractAddress) public {
        nftContractAddress = _contractAddress;
    }

    // The getSVG() function will take in the score, privacy boolean, background color, and tokenId to generate an abi encoded string with SVG data
    function getSVG(
        uint256 _score,
        bool _privacy,
        string _color,
        uint256 _tokenId
    ) {
        string[7] memory parts;
        parts[0] = "<svg viewBox='0 0 400 400'><style>.a { fill: ";
        parts[1] = _color;
        parts[2] = "#0000; font-size: 18px; }</style><text x='10' y='10' class='a'>Token #";
        parts[3] = string(_tokenId);
        if(_privacy){
            parts[4] = "";
            parts[5] = "";
        } else {
            parts[4] = "</text><text x='350' y='350' class='a'>ImpactScore: ";
            parts[5] = string(_score);
        }
        parts[6] = "</text></svg>";

        return string(abi.encodePacked(parts[0],parts[1],parts[2],parts[3],parts[4],parts[5],parts[6]);)
    }

    function tokenURI(
        address lockAddress,
        address operator,
        address owner,
        uint256 keyId,
        uint256 expirationTimestamp
    ) external view returns (string memory) {
        // get lock instance
        IPublicLockV10 lock = IPublicLockV10(lockAddress);

        // if NFT contract is not set, returns default lock tokenURI
        if (nftContractAddress == address(0)) {
            return lock.tokenURI(keyId);
        }

        // check nft ownership
        IERC721 nft = IERC721(nftContractAddress);
        bool ownsNft = nft.balanceOf(owner) > 0;
        console.log("== owns nft:", ownsNft);

        // check key validity
        bool hasValidKey = lock.getHasValidKey(owner);
        console.log("== has valid key:", hasValidKey);

        // calculate background color from score
        // TODO: find a way to make this transparent so that the SVG digits can lay on top of the video NFT

        string memory color = "grey";
        if (score > 50) {
            color = "green";
        } else {
            color = "red";
        }

        string memory svgData = getSVG(score, isPrivate(keyId), color, tokenId);

        string memory json = Base64.encode(
            bytes(
                string(
                    abi.encodePacked(
                        '{"name": "Impact NFT", "description": "", "image_data": "',
                        bytes(svgData),
                        '"}'
                    )
                )
            )
        );
        return string(abi.encodePacked("data:application/json;base64,", json));
    }
}

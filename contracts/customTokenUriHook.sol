// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

// Import this file to use console.log
import "hardhat/console.sol";
import "@unlock-protocol/contracts/dist/Hooks/ILockTokenURIHook.sol";

contract customTokenUriHook is ILockTokenURIHook {
    mapping(address=>bool) public privacy;
    mapping(address=>address[]) public accessList;
    mapping(address=>uint256) public score;
    
    function giveAccess(address[] calldata whitelist) public {
      for(uint i=0;i<whitelist.length;i++)
      accessList[msg.sender].push(whitelist[i]);
    }
    function removeAccess(address profile) public {
      uint256 length=accessList[msg.sender].length;
      for(uint i=0; i<length;i++)
      {
      if(accessList[msg.sender][i]==profile)
      {
        accessList[msg.sender][i]=accessList[msg.sender][length-1];
        accessList[msg.sender].pop();
      }
      }
    }
    function setPrivacy(bool value) public {
      if(value==true){
        setScore(msg.sender,0);
      }
      else{
        //updatescore();
      }
    }
    function setScore(address profileAdd,uint256 newScore) internal {
      score[profileAdd]=newScore;
    }
    function tokenURI(
    address lockAddress,
    address operator,
    address owner,
    uint256 keyId,
    uint expirationTimestamp
  ) external view returns(string memory) {
    return "abc";
  }
}
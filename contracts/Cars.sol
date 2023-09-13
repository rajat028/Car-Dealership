// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "hardhat/console.sol";

contract Cars is ERC721URIStorage, Pausable {
    address public owner;

    uint public tokenSupply;

    error NotApproved();

    constructor(
        string memory _name,
        string memory _symbol
    ) ERC721(_name, _symbol) {
        owner = msg.sender;
    }

    function safeMint(string memory _tokenURI) public whenNotPaused {
        tokenSupply++;

        _safeMint(msg.sender, tokenSupply);
        _setTokenURI(tokenSupply, _tokenURI);
    }

    function burn(uint tokenId) public {
        if (!_isApprovedOrOwner(msg.sender, tokenId)) {
            revert NotApproved();
        }
        tokenSupply--;
        _burn(tokenId);
    }
}

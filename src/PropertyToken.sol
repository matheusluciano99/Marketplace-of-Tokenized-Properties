// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";

contract PropertyToken is ERC721URIStorage {
    uint256 private _tokenIdCounter;

    constructor() ERC721("PropertyToken", "PPT") {
        _tokenIdCounter = 0;
    }

    // mints the property token
    function mint(address to, string memory tokenURI) public returns (uint256) {
        uint256 tokenId = _tokenIdCounter;
        _tokenIdCounter++;
        _mint(to, tokenId);
        _setTokenURI(tokenId, tokenURI);

        return tokenId;
    }

    function getTokenIdCounter() external view returns (uint256) {
        return _tokenIdCounter;
    }
}
